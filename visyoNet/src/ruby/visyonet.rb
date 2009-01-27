# :include: visyonet/README.txt
#
# == Other Info
# 
# Version:: $Id:$
# Author:: Max Ott <max(at)ott.name>
# Copyright 2006, Max Ott, All rights reserved.
# 
require 'util/mobject'
require 'rexml/document'
require "visyonet/visHttpServer"
require "visyonet/context"
require "visyonet/session"

require 'optparse'

module VisyoNet
  VY_VERSION = "1.2.0"
  VY_REVISION = "$Revision: 000 $".split(":")[1].chomp("$").strip
  VY_VERSION_STRING = "Visyonet Version #{VY_VERSION} (#{VY_REVISION})"

  @@blockWebServer = false
    
  def self.start(block = false)
    
    logConfigFile = nil
    startTime = Time.now

    testPath = nil
    testDataSource = testVisMapping = false
    
    opts = OptionParser.new
    opts.banner = "Usage: visyonet [options] defFile"
    
    opts.on("-n", "--no-web-server", "Do not start the web server") { @@blockWebServer = true }

    opts.on("--log FILE", "File containing logging configuration information") {|file| 
      logConfigFile = file
    }

    opts.on("--test-source PATH", "Request one sample from source and print") { |path|
      testPath = path
      testDataSource = true
    }
    opts.on("--test-mapping PATH", "Visualize one sample") { |path|
      testPath = path
      testDataSource = testVisMapping = true
    }
    
    opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }
    opts.on_tail("-v", "--version", "Show the version") { 
      puts VY_VERSION_STRING
      exit
    }
    
    begin 
      rest = opts.parse(ARGV)
      # create the loggers.
      if (logConfigFile == nil)
        logConfigFile = findDefaultLogConfigFile
      end
      
      MObject.initLog('visyonet', '', logConfigFile)
      MObject.info('start', VY_VERSION_STRING)
      
      if (rest.length == 0)
        MObject.error('start', "Missing configuration file")
        exit(-1)
      end
      rest.each { |fileName|
        processConfigFile(fileName)      
      }
      
      if (testDataSource)
        context = Context[testPath]
        session = VisSession.instance(nil, context)
        model = session.getDataModel()
        puts "\nNodes:"
        model['nodes'].each_value {|n| puts n.to_s}
        puts "\nLinks:"
        model['links'].each_value {|l| puts l.to_s}
        if (testVisMapping)
          canvas = session.convert(model)
          puts canvas.to_XML
        end
      end


    rescue SystemExit => err
      exit
    rescue Exception => ex
      begin 
        bt = ex.backtrace.join("\n\t")
        puts "Exception: #{ex} (#{ex.class})\n\t#{bt}"
      rescue Exception
      end
      exit(-1)
    end

    if (block)
      @@mutex = Mutex.new
      @@running = ConditionVariable.new  
      @@mutex.synchronize {
        @@running.wait(@@mutex)
      }
    end  
  end
  
  def self.stop()
    if (@@mutex != nil)
      @@mutex.synchronize {
        @@running.signal
      }
    end
  end  
  
  def self.processConfigFile(fileName, type = 'xml')
    if ! File.exists?(fileName)
      raise "Can't find config file '#{fileName}'"
    end
    case type
    when 'xml'
      file = File.new(fileName)
      content = file.read()
      file.close()
      processConfig(content, File.dirname(fileName))
    when 'ruby'
      file = File.new(fileName)
      content = file.read()
      file.close()
      #VisyoNet.module_eval(content, fileName, 1)
      load(fileName)
    else
      raise "Unknown Include type '#{type}'"
    end
  end
  
  def self.processConfig(text, includeDir = "")
    xmlDoc = REXML::Document.new(text)
    root = xmlDoc.root
    if (root.name != 'Visyonet')
      MObject.error('processConfig', 
        "Doesn't appear to be a proper config file - starts with '#{root.name}'")
      return false
    end
    root.elements.each { |el|
      case el.name
      when "Include"
        if (file = el.attributes['path'])
          if (file[0] != ?/)
            file = "#{includeDir}/#{file}"
          end
          processConfigFile(file, el.attributes['type'] || 'xml')
        else
          MObject.error('processConfig', "Missing 'path' attribute in 'Include' tag ")
        end
      when "DataSource"
        DataSource.processConfig(el)
      when "VisMapping"
        VisMapping.processConfig(el)
      when "Context"
        Context.processConfig(el)   
      when "HttpServer"
        if (! @@blockWebServer)
          VisHttpServer.instance.processConfig(el)   
          VisHttpServer.instance.start
        end
      else
        MObject.error('processConfig', "Unknown config tag '#{el.name}'")
      end
    }
  end
  
  def self.findDefaultLogConfigFile()
    log = ENV['VISYONET_LOG']
    if log != nil
      if ! File.exists?(log)
        raise "Can't find log file '#{log}'"
      end
      return log
    end
    logFile = "visyonet_log.xml"
    [".#{logFile}", "~/.#{logFile}", "/etc/visyonet/#{logFile}", "log/default.xml"].each {|f|
      if File.exists?(f)
        return f
      end
    }
    return nil
  end
  
  def self.blockMain()
    if (!@@blockWebServer)
      sleep
    end
  end
  
end
    
VisyoNet::start()
VisyoNet::blockMain()

   
