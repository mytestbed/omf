require 'log4r'
require 'singleton'

OMF_LOGGER_LOG_FILE = "/tmp/omf.log"

module OmfCommon
  # A singleton class where a global logger instance can be used in the project
  #
  class Logger
    include Singleton
    attr_reader :logger

    def initialize
      @logger= Log4r::Logger.new("OMF")

      formatter = Log4r::PatternFormatter.new(:date_pattern => "%F %T %z",
                                              :pattern => "%d [%l] %M")
      stdout_outputter = Log4r::StdoutOutputter.new("console", :formatter => formatter)
      file_outputter = Log4r::FileOutputter.new("file", :filename => OMF_LOGGER_LOG_FILE, :trunc => false, :formatter => formatter)

      @logger.outputters << stdout_outputter
      @logger.outputters << file_outputter
      @logger.level = Log4r::DEBUG
    end
  end
end

module Kernel
  # Helper method for global logging.
  # omf_logger.debug 'Message'
  #
  def omf_logger
    OmfCommon::Logger.instance.logger
  end
end
