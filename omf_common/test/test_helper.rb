# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'simplecov'
SimpleCov.start { add_filter "/test" }

gem 'minitest'
require 'minitest/autorun'
require 'minitest/pride'
require 'minitest/spec'
require 'minitest/mock'

require 'evented-spec'
require 'mocha/setup'

#require 'em/minitest/spec'

require 'omf_common'
#require 'blather/client/dsl'

#require 'singleton'

#OmfCommon::Message.init(type: :xml)

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

class OmfCommon::Auth::CertificateStore
  def self.reset
    @@instance = nil
  end
end
