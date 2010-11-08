#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#
#
require 'rubygems'
require 'date'
require 'log4r'
require 'log4r/configurator'
#include Log4r

#
# An extended object class with support for logging
#
class MObject

  @@logger = nil
  @@rootLoggerName = nil

  #
  # Initialize the logger. The 'appName' is the name of the root
  # logger. 'AppInstance' and 'appName' are available as parameters
  # in the log configuration file. The 'params' hash can optionally
  # contain information on how to find a configuration file. The
  # following keys are used:
  #
  #  * :env - Name of environment variable holding dominant config file
  #  * :fileName - Name of config file [#{appName}_log.xml]
  #  * :searchPath - Array of directories to look for 'fileName'
  #
  def MObject.initLog(appName, appInstance = nil, params = {})
	  
    @@rootLoggerName = appName
    @@logger = Log4r::Logger.new(appName)

    configFile = params[:configFile]
    if (configFile == nil && logEnv = params[:env])
        configFile = ENV[logEnv]
    end
    if (configFile != nil)
      # Make sure log exists ...
      configFile = File.exists?(configFile) ? configFile : nil
    else
      name = params[:fileName] || "#{appName}_log.xml"
      if ((searchPath = params[:searchPath]) != nil)
        logDir = searchPath.detect {|dir|
          File.exists?("#{dir}/#{name}")
        }
        #puts "logDir '#{logDir}:#{logDir.class}'"
        configFile = "#{logDir}/#{name}" if logDir != nil
      end
    end
    #puts "config file '#{configFile}'"
    if configFile != nil
      if (appInstance == nil)
        appInstance = DateTime.now.strftime("%F-%T").split(':').join('-')
      end
      Log4r::Configurator['appInstance'] = appInstance
      Log4r::Configurator['appName'] = appName
      begin
        Log4r::Configurator.load_xml_file(configFile)
      rescue Log4r::ConfigError => ex
        @@logger.outputters = Log4r::Outputter.stdout
        MObject.error("Log::Config", ex)
      end
    else
      # set default behavior
      @@logger.outputters = Log4r::Outputter.stdout
    end
  end

  def MObject.logger(category = nil)
    if @@logger == nil || category == nil
      return @@logger
    end
    name = "#{@@rootLoggerName}::#{category}"
    logger = Log4r::Logger[name]
    if logger == nil
      logger = Log4r::Logger.new(name)
    end
    return logger
  end

  def MObject.debug(context, *message)
    logger = MObject.logger(context)
    if logger == nil
      puts "DEBUG #{context}: #{message.join('')}"
    else
      logger.debug(message.join('')) if logger.debug?
    end
  end

  def MObject.info(context, *message)
    logger = MObject.logger(context)
    if logger == nil
      puts " INFO #{context}: #{message.join('')}"
    else
      logger.info(message.join('')) if logger.info?
    end
  end

  def MObject.warn(context, *message)
    logger = MObject.logger(context)
    if logger == nil
      puts " WARN #{context}: #{message.join('')}"
    else
      logger.warn(message.join('')) if logger.warn?
    end
  end

  def MObject.error(context, *message)
    logger = MObject.logger(context)
    if logger == nil
      puts "ERROR #{context}: #{message.join('')}"
    else
      logger.error(message.join('')) if logger.error?
    end
  end

  def MObject.fatal(context, *message)
    logger = MObject.logger(context)
    if logger == nil
      puts "FATAL #{context}: #{message.join('')}"
    else
      logger.fatal(message.join(''))
    end
  end

  @logger

  def initialize (loggerCategory = nil)
    logger(loggerCategory)
  end

  def debug(*message)
    if @@logger == nil
      puts "DEBUG: #{message.join('')}"
    else
      if (@logger == nil)
        logger
      end
      @logger.debug(message.join('')) if @logger.debug?
    end
  end

  def info(*message)
    if @@logger == nil
      puts " INFO: #{message.join('')}"
    else
      if (@logger == nil)
        logger
      end
      @logger.info(message.join('')) if @logger.info?
    end

  end

  def warn(*message)
    if @@logger == nil
      puts " WARN: #{message.join('')}"
    else
      if (@logger == nil)
        logger
      end
      @logger.warn(message.join('')) if @logger.warn?
    end
  end

  def error(*message)
    if @@logger == nil
      puts "ERROR: #{message.join('')}"
    else
      if (@logger == nil)
        logger
      end
      @logger.error(message.join('')) if @logger.error?
    end
  end

  def fatal(*message)
    if @@logger == nil
      puts "FATAL: #{message.join('')}"
    else
      if (@logger == nil)
        logger
      end
      @logger.fatal(message.join('')) if @logger.fatal?
    end
  end

  private
  def logger(category = nil)
    category = self.class.to_s if !category
    if @logger == nil
      @logger = MObject.logger(category)
    end
    return @logger
  end

end
