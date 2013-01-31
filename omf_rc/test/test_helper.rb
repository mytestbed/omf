require 'simplecov'
SimpleCov.start { add_filter "/test" }

gem 'minitest'
require 'minitest/autorun'
require 'minitest/pride'

require 'omf_rc'
require 'omf_rc/resource_factory'
require 'omf_rc/resource_factory'
require 'omf_common/comm/xmpp/communicator'

# Default fixture directory
FIXTURE_DIR = "#{File.dirname(__FILE__)}/fixture"

# Shut up all the loggers
#Logging.logger.root.clear_appenders

# Reading fixture file
def fixture(name)
  File.read("#{FIXTURE_DIR}/#{name.to_s}")
end
