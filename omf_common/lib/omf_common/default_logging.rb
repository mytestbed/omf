# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'logging'

module OmfCommon
  module DefaultLogging
    # Use global default logger from logging gem
    include Logging.globally

    Logging.appenders.stdout(
      'default_stdout',
      :layout => Logging.layouts.pattern(:date_pattern => '%F %T %z',
                                         :pattern => '[%d] %-5l %c: %m\n'))
    Logging.logger.root.appenders = 'default_stdout'
    Logging.logger.root.level = :info

    # Alias logging method using default logger
    #
    # @example
    #
    #   info 'Information'
    #   # Additional logger name will generate a new child logger in the context of default logger
    #   info 'Information', 'logger name'
    #
    def info(*args, &block)
      get_logger(args[1]).info(args[0], &block)
    end

    # @see #info
    def debug(*args, &block)
      get_logger(args[1]).debug(args[0], &block)
    end

    # @see #info
    def error(*args, &block)
      get_logger(args[1]).error(args[0], &block)
    end

    # @see #info
    def fatal(*args, &block)
      get_logger(args[1]).fatal(args[0], &block)
    end

    # @see #info
    def warn(*args, &block)
      get_logger(args[1]).warn(args[0], &block)
    end

    # Log a warning message for deprecated methods
    def warn_deprecation(deprecated_name, *suggest_names)
      logger.warn "[DEPRECATION] '#{deprecated_name}' is deprecated. Please use '#{suggest_names.join(', ')}' instead."
    end

    def warn_removed(deprecated_name)
      define_method(deprecated_name) do |*args, &block|
        logger.warn "[DEPRECATION] '#{deprecated_name}' is deprecated and not supported. Please do not use it."
      end
    end

    private

    def get_logger(name = nil)
      name.nil? ? logger : Logging::Logger["#{logger.name}::#{name.to_s}"]
    end
  end
end
