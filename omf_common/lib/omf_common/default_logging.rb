require 'logging'

module OmfCommon
  module DefaultLogging
    # Use global default logger from logging gem
    include Logging.globally

    Logging.appenders.stdout(
      'default_stdout',
      :layout => Logging.layouts.pattern(:date_pattern => '%F %T %z',
                                         :pattern => '[%d] %-5l %c: %m\n',
                                         :color_scheme => 'default'))
    Logging.logger.root.appenders = 'default_stdout'
    Logging.logger.root.level = :info
  end
end
