require 'simplecov'
SimpleCov.start { add_filter "/test" }

gem 'minitest'
require 'minitest/autorun'
require 'minitest/pride'
require 'minitest/spec'
require 'minitest/mock'
require 'em/minitest/spec'
require 'mocha/setup'

require 'omf_common'
require 'blather/client/dsl'

require 'singleton'

OmfCommon::Message.init(type: :xml)

# Shut up all the loggers
Logging.logger.root.clear_appenders

# Add reset to singleton classes
#
class OmfCommon::Comm
  def self.reset
    @@instance = nil
  end
end

class OmfCommon::Eventloop
  def self.reset
    @@instance = nil
  end
end
