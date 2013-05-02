require 'simplecov'
SimpleCov.start { add_filter "/test" }

gem 'minitest'
require 'minitest/autorun'
require 'minitest/pride'
require 'mocha/setup'

require 'omf_ec'

# Default fixture directory
FIXTURE_DIR = "#{File.dirname(__FILE__)}/fixture"

# Shut up all the loggers
Logging.logger.root.clear_appenders

# Reading fixture file
def fixture(name)
  File.read("#{FIXTURE_DIR}/#{name.to_s}")
end

class OmfCommon::Eventloop
  def self.reset
    @@instance = nil
  end
end

class OmfEc::Experiment
  def self.reset
    instance.instance_eval do
      @groups = []
      @events = []
      @app_definitions = Hashie::Mash.new
      @sub_groups = Hashie::Mash.new
      @cmdline_properties = Hashie::Mash.new
    end
  end
end

class OmfEc::ExperimentProperty
  def self.reset
    @@properties = Hashie::Mash.new
    @@creation_observers = []
  end
end


