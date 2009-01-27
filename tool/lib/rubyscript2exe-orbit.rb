#!/usr/bin/ruby
require 'set'


# Ruby search path. First entry will be replaced with the directory
# where the start file is located.
PATH = [ nil, "/usr/lib/ruby/1.8", "/usr/lib/ruby/1.8/i486-linux", "/usr/lib/ruby/1.8/i386-linux" ] 

BIN_FILES = ["/usr/bin/ruby", "/usr/lib/libruby1.8.so.1.8", "/lib/ld-linux.so.2"]

KNOWN_DEPENDENCIES = {
  "digest/md5" => ["digest"],
  "rexml/encoding" => ["rexml/encodings/CP-1252", "rexml/encodings/ICONV",
      "rexml/encodings/ISO-8859-15", "rexml/encodings/SHIFT_JIS",
      "rexml/encodings/US-ASCII", "rexml/encodings/UTF-8",
      "rexml/encodings/EUC-JP",  "rexml/encodings/ISO-8859-1",
      "rexml/encodings/SHIFT-JIS", "rexml/encodings/UNILE",
      "rexml/encodings/UTF-16"]
}

OK_TO_FAIL = Set.new ["romp", "uconv", "gtk", "gtk2", "fox", "tk", "Win32API", "etc.so"  ] 


# Top directory of template tar
TEMPLATE_DIR = "eee_template"


##############


$verbose = false
$version = "?.?"
$appName = nil

Dirs = Set.new


#$app_c = ['c echo source %tempdir%/eee.sh %tempdir% %tempdir%/bin/ruby -r %tempdir%/eee.rb -r %tempdir1%/bootstrap.rb %tempdir1%/empty.rb %tempdir%/app/', ' %quotedparms% | sh -s']

#$app_c = ['c %tempdir%/eee.sh %tempdir% %tempdir%/bin/ruby -r %tempdir%/eee.rb -r %tempdir1%/bootstrap.rb %tempdir1%/empty.rb %tempdir%/app/', ' %quotedparms%']

#$app_c = ['c %tempdir%/eee.sh %tempdir% %tempdir%/bin/ruby -r %tempdir%/eee.rb -r %tempdir%/bootstrap.rb %tempdir%/empty.rb %tempdir%/app/', ' %quotedparms%']

$app_c = ['c sh %tempdir%/eee.sh %tempdir% ', ' %quotedparms%']

Packages = Hash.new
Outstanding = []

def checkoutFile(file)
  puts "Checking #{file}" if $verbose
  IO.popen("grep -h -E '^[[:space:]]*require' #{file}").each_line { |l|
    n = l.chomp.strip.split(/[ \t()]/)[1]
    #puts "Looking for =#{n}="
    if ! (n[0] == ?" || n[0] == ?')
      puts "WARN: Ignoring '#{n}' in #{file} as it appears to be a variable" 
    else 
      p = n[1..-2]
      #puts "Found #{p}"
      addPackage(p)
    end
  }
end

def addPackage(p)
  if (!Packages.key?(p))	
#    Packages[p] = nil
    Outstanding << p
    if (deps = KNOWN_DEPENDENCIES[p]) != nil
      deps.each { |d|
        addPackage(d)
      } 
    end
  end
end

def findFile(n)
#  puts "check #{n} in #{PATH.join(':')}"
    PATH.inject(nil) { |f, p|
      if (f == nil)    
	fName = "#{p}/#{n}"
	if File.readable?(fName)
	  f = fName
	end
      end
      f
    }
end


def findDependencies(startFile)
  checkoutFile startFile
  while Outstanding.length != 0
    a = Outstanding.clone
    Outstanding.clear
    a.each { |n|
      if (n =~ /\.rb/) == nil
	if (file = findFile("#{n}.rb")) == nil  
	  file = findFile("#{n}.so")
	end
      else
	file = findFile(n)
      end
      if (file == nil)
	if ! OK_TO_FAIL.include?(n)
	  puts "ERROR: Can't find file for package #{n}"
	end
      else	
	puts "#{n} => #{file}" if $verbose
	Packages[n] = file
	checkoutFile(file) 
      end
    }
  end
end

def makeDir (name, topDir, indexFile)
  dir = name.split('/')[0..-2]
  dir.inject(nil) { |prefix, name|
    d = prefix == nil ? name : "#{prefix}/#{name}"
    if Dirs.add?(d) != nil
      system("mkdir #{topDir}/#{d}")
      indexFile.puts("d lib/#{d}")
    end	  
    d
  }
  return dir.join('/') 
end
	
# Return the extension to add to name if it doesn't have one
#
def findExtension(name, file)
  if (name =~ /\./) != nil
    return nil
  end
#  puts "name: #{name} file: #{file}"
  last = file.split('/')[-1]
  return last[last =~ /\./..-1]
end 


def extractTemplate(template, buildDir, templateDir) 
  puts "Extracting template '#{template}' into #{buildDir}"
  dir = buildDir + '/' + templateDir
  if File.exists?(dir)
    puts "Removing old template"
    if ! system("rm -rf #{dir}")
      raise "Can't delete old template directory '#{dir}' (#{$?})"
    end
  end
  if ! system("d=`pwd`; cd #{buildDir}; tar xf $d/#{template}")
    raise "Cannot extract template: $?"
  end
end

def buildAppEee(startFile, installDir, appName = nil)
  index = File.open(installDir + "/app.eee", "a+")

  appFile = File.basename(startFile)
  system("sed -e's/@VERSION@/#{$version}/' #{startFile} > #{installDir}/app/#{appFile}")
  index.puts "f app/#{appFile}"

  libDir = installDir + "/lib"

  Packages.each { |name, file|
    dir = makeDir(name, libDir, index)
    system("cp -p #{file} #{libDir}/#{dir}")
    dest = dir != "" ? "lib/#{dir}/#{name}" : "lib/#{name}"
    ext = findExtension(name, file)
    index.puts "f lib/#{name}#{ext}"
  }

  # copy the current ruby binary and library into bin
  binDir = installDir + "/bin"
  BIN_FILES.each {|file|
    system("cp -p #{file} #{binDir}")
    name = File.basename(file)
    index.puts "f bin/#{name}"
  }

  index.puts $app_c.join(appFile)
  index.close

  if (appName == nil)
    appName = appFile.split('.')[0]
  end
  system("cd #{installDir}; ./eee_linux app.eee ../#{appName}")
end


require 'optparse'

buildDir = "build"
templateTar = "tool/lib/eee_template.tar"

opts = OptionParser.new
opts.banner = "Usage: #{File.basename($0)} [options] startFile"

opts.on("-b", "--base_dir DIRECTORY", "Base directory for app specific files") { |d|
  PATH[0] = d
}

opts.on("-d", "--build_dir DIRECTORY", "Directory to build executable") { |d|
  buildDir = d
}

opts.on("-n", "--app_name NAME", "Name of application binary [start_file]") { |name|
  $appName = name
}

opts.on("-t", "--template TEMPLATE_FILE", "Template file for EEE") { |t|
  templateTar = t
}

opts.on("-v", "--verbose", "Display activity information") { 
  $verbose = true 
}

opts.on("-V", "--version version", 
	"Replace the @VERSION@ string in app with this argument") { |v|
  $version = v
}

opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }

begin 
  rest = opts.parse(ARGV)
  if rest.length != 1
    puts opts
    exit -1
  end
  
  #startFile = "../../src/ruby/nodeHandler.rb"
  startFile = rest[0]
  if PATH[0] == nil
    PATH[0] = File.dirname(startFile)
  end

  # get dependencies on main file
  findDependencies(startFile)
  extractTemplate(templateTar, buildDir, TEMPLATE_DIR)
  buildAppEee(startFile, buildDir + "/" + TEMPLATE_DIR, $appName)
  
rescue SystemExit => err
  exit
rescue Exception => ex
  begin 
    bt = ex.backtrace.join("\n\t")
    puts "Exception: #{ex} (#{ex.class})\n\t#{bt}"
  rescue Exception
  end
  exit -1
end


	 	

