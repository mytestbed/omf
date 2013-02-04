require 'simplecov'
SimpleCov.start { add_filter "/test" }

gem 'minitest'
require 'minitest/autorun'
require 'minitest/pride'

require 'omf_common'

OmfCommon::Message.init(type: :xml)

# Shut up all the loggers
Logging.logger.root.clear_appenders
