require 'log4r'
require 'log4r/configurator'
include Log4r

#
# An extended object class with support for logging
#
class MObject

  @@logger = nil
  @@rootLoggerName = nil

  def MObject.initLog(appName, appInstance = nil, configFile = nil)
    @@rootLoggerName = appName  
    @@logger = Logger.new(appName)
    if configFile != nil
      if (appInstance == nil)
        appInstance = DateTime.now.strftime("%F-%T").split(':').join('-')
      end
      Configurator['appInstance'] = appInstance
      Configurator['appName'] = appName
      begin
	Configurator.load_xml_file(configFile)
      rescue Log4r::ConfigError => ex
	@@logger.outputters = Outputter.stdout
	MObject.error("Log::Config", ex)
      end
    else
      @@logger.outputters = Outputter.stdout
    end
  end
  
  def MObject.logger(category = nil)
    if @@logger == nil || category == nil
      return @@logger
    end
    name = "#{@@rootLoggerName}::#{category}"
    logger = Logger[name]
    if logger == nil
      logger = Logger.new(name)
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
  
  private
  def logger(category = self.class.to_s)
    if @logger == nil
      @logger = MObject.logger(category)
	end
	return @logger
  end
  
end
