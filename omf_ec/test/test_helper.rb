# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'simplecov'
SimpleCov.start { add_filter "/test" }

gem 'minitest'
require 'minitest/autorun'
require 'minitest/pride'
require 'mocha/setup'

require 'evented-spec'

require 'omf_ec'

# Shut up all the loggers
Logging.logger.root.clear_appenders

def uninit
  OmfEc::Experiment.reset
  OmfEc::ExperimentProperty.reset
  OmfCommon::Eventloop.reset
end

class OmfCommon::Eventloop
  def self.reset
    @@instance = nil
  end
end

class OmfEc::Experiment
  def self.reset
    Singleton.__init__(self)
  end
end

class OmfEc::ExperimentProperty
  def self.reset
    Singleton.__init__(self)
  end
end
