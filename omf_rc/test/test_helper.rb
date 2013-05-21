# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'simplecov'
SimpleCov.start { add_filter "/test" }

gem 'minitest'
require 'minitest/autorun'
require 'minitest/pride'

require 'omf_rc'
require 'omf_rc/resource_factory'

# Default fixture directory
FIXTURE_DIR = "#{File.dirname(__FILE__)}/fixture"

# Shut up all the loggers
Logging.logger.root.clear_appenders

# Reading fixture file
def fixture(name)
  File.read("#{FIXTURE_DIR}/#{name.to_s}")
end

OmfCommon::Message.init(type: :xml)

