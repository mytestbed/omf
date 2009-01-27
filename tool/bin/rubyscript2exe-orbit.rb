#!/usr/bin/ruby
require 'set'

DIR = "../../src/ruby"
PATH = [ DIR, "/usr/lib/ruby/1.8", "/usr/lib/ruby/1.8/i386-linux" ] 

KNOWN_DEPENDENCIES = {
  "digest/md5" => ["digest"]
}

InstallDir = "../../build/eee_template"
AppFile = 'nodeHandler.rb'
app_c = ['c echo source %tempdir%/eee.sh %tempdir% %tempdir%/bin/ruby -r %tempdir%/eee.rb -r %tempdir1%/bootstrap.rb %tempdir1%/empty.rb %tempdir%/app/', ' %quotedparms% | sh -s']

Packages = Hash.new
Outstanding = []

def checkoutFile(file)
  IO.popen("grep -h -E '^\\s*require' #{file}").each_line { |l|
    p = l.split[1][1..-2]
#    puts "Found #{p}"
    addPackage(p)
  }
end

def addPackage(p)
  if (!Packages.key?(p))	
    Packages[p] = nil
    Outstanding << p
    if (deps = KNOWN_DEPENDENCIES[p]) != nil
      deps.each { |d|
        addPackage(d)
      } 
    end
  end
end

def findFile(n)
#puts "check #{n}"
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

checkoutFile "#{DIR}/nodeHandler.rb"

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
      puts "ERROR: Can't find file for package #{n}"
    else	
      p "#{n} => #{file}"
      Packages[n] = file
      checkoutFile(file) 
    end
  }
end

LibDir = InstallDir + "/lib"
Dirs = Set.new
Index = File.open(InstallDir + "/app.eee", "a+")

Index.puts "f app/#{AppFile}"

def makeDir (name)
  dir = name.split('/')[0..-2]
  dir.inject(nil) { |prefix, name|
    d = prefix == nil ? name : "#{prefix}/#{name}"
    if Dirs.add?(d) != nil
      system("mkdir #{LibDir}/#{d}")
      Index.puts("d lib/#{d}")
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
  last = file.split('/')[-1]
  return last[last =~ /\./..-1]
end 

Packages.each { |name, file|
  dir = makeDir(name)
  system("cp -p #{file} #{LibDir}/#{dir}")
  dest = dir != "" ? "lib/#{dir}/#{name}" : "lib/#{name}"
  ext = findExtension(name, file)
  Index.puts "f lib/#{name}#{ext}"
}

Index.puts app_c.join(AppFile)
Index.close
