#!/usr/bin/ruby
require 'set'


# Ruby search path. First entry will be replaced with the directory
# where the start file is located.
PATH = ["/usr/lib/ruby/1.8", "/usr/lib/ruby/1.8/i486-linux", "/usr/lib/ruby/1.8/i386-linux" ] 

SBIN_FILES = ["/usr/bin/ruby1.8", "/usr/lib/libruby1.8.so.1.8", "/lib/ld-linux.so.2"]

KNOWN_DEPENDENCIES = {
  "digest/md5" => ["digest"],
  "rexml/encoding" => ["rexml/encodings/CP-1252", "rexml/encodings/ICONV",
      "rexml/encodings/ISO-8859-15", "rexml/encodings/SHIFT_JIS",
      "rexml/encodings/US-ASCII", "rexml/encodings/UTF-8",
      "rexml/encodings/EUC-JP",  "rexml/encodings/ISO-8859-1",
      "rexml/encodings/SHIFT-JIS", "rexml/encodings/UNILE",
      "rexml/encodings/UTF-16"]
}

OK_TO_FAIL = Set.new ["romp", "uconv", "gtk", "gtk2", "fox", "tk", "Win32API", "etc.so" '\#{load_file}' ] 




##############


$verbose = false
$version = nil # "?.?"
$appName = 'foo'

Dirs = Set.new


Packages = Hash.new
Outstanding = []

def checkoutFile(file)
  puts "Checking #{file}" if $verbose
  IO.popen("grep -h -E '^[[:space:]]*require ' #{file}").each_line { |l|
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
	  if (file = findFile("#{n}.so")) == nil
	    # Thierry @ NICTA:
	    # add this to also support lookup when 'require' already provide a 
	    # name with an extension 
	    # (e.g. this is the case for "require thread.so" in thread.rb)
	    (file = findFile("#{n}")) == nil  
	  end
	end
      else
	file = findFile(n)
      end
      if (file == nil)
	if ! OK_TO_FAIL.include?(n)
	  puts "ERROR: Can't find file for package <#{n}>"
	end
      else	
	puts "#{n} => #{file}" if $verbose
	Packages[n] = file
	checkoutFile(file) 
      end
    }
  end
end

def makeDir (name, topDir)
  dir = name.split('/')[0..-2]
  dir.inject(nil) { |prefix, name|
    d = prefix == nil ? name : "#{prefix}/#{name}"
    if Dirs.add?(d) != nil
      system("mkdir #{topDir}/#{d}")
#      indexFile.puts("d lib/#{d}")
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


def extractTemplate(templateDir, buildDir, appName) 
  dir = buildDir + '/' + appName
#  if $version != nil
#    dir += ('-' + $version) 
#  end
  puts "Copying template '#{templateDir}' to '#{dir}'"
  if File.exists?(dir)
    puts "Removing old template"
    if ! system("rm -rf #{dir}")
      raise "Can't delete old template directory '#{dir}' (#{$?})"
    end
  end

  if ! system("mkdir #{dir}; tar -C #{templateDir} --exclude=.svn --exclude='*~' -cf - . | (cd #{dir}; tar -xf -)")
    raise "Cannot extract template: $?"
  end
  dir
end

def buildAppEee(startFile, installDir, appName = nil)
#  index = File.open(installDir + "/app.eee", "a+")

  appFile = File.basename(startFile)
  system("sed -e's/@VERSION@/#{$version || '?:?'}/' #{startFile} > #{installDir}/app/#{appFile}")
  system("sed -e's/@@APP_NAME@@/#{appName}/' #{installDir + '/INSTALL.sh.tmpl'} | sed -e's/@@APP_SCRIPT@@/#{appFile}/' > #{installDir}/INSTALL.sh")
  system("rm -f #{installDir + '/INSTALL.sh.tmpl'}")
#  index.puts "f app/#{appFile}"

  libDir = installDir + "/lib"

  Packages.each { |name, file|
    dir = makeDir(name, libDir)
    system("cp -p #{file} #{libDir}/#{dir}")
    dest = dir != "" ? "lib/#{dir}/#{name}" : "lib/#{name}"
    ext = findExtension(name, file)
#    index.puts "f lib/#{name}#{ext}"
  }

  # copy the current ruby binary and library into bin
  binDir = installDir + "/sbin"
  SBIN_FILES.each {|file|
    system("cp -p #{file} #{binDir}")
    name = File.basename(file)
#    index.puts "f bin/#{name}"
  }

#  index.puts $app_c.join(appFile)
#  index.close

  if (appName == nil)
    appName = appFile.split('.')[0]
  end
#  system("cd #{installDir}; ./eee_linux app.eee ../#{appName}")
end


require 'optparse'

buildDir = "build"
templateDir = "tool/lib/dist_template"

opts = OptionParser.new
opts.banner = "Usage: #{File.basename($0)} [options] startFile"

opts.on("-b", "--base_dir DIRECTORY", "Base directory for app specific files") { |d|
  PATH.insert(0, d)
}

opts.on("-d", "--build_dir DIRECTORY", "Directory to build executable") { |d|
  buildDir = d
}

opts.on("-n", "--app_name NAME", "Name of application binary [start_file]") { |name|
  $appName = name
}

opts.on("-t", "--template TEMPLATE_DIR", "Template dir") { |t|
  templateDir = t
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
  dir = extractTemplate(templateDir, buildDir, $appName)
  buildAppEee(startFile, dir, $appName)
  
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


	 	

