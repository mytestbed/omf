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

def mock_comm_in_res_proxy
  @comm = mock

  [:inform, :publish, :unsubscribe].each do |m_name|
    OmfCommon::Comm::Topic.any_instance.stubs(m_name)
  end

  @comm.class_eval do
    define_method(:subscribe) do |*args, &block|
      block.call(self.create_topic("xmpp://localhost/#{args[0]}"))
    end
  end

  OmfCommon.stubs(:comm).returns(@comm)
end

def mock_topics_in_res_proxy(options)
  @topics = {}.tap do |hash|
    options[:resources].each do |r|
      hash[r] = OmfCommon::Comm::Topic.create(:parent)
    end
  end

  if (default_r = options[:default]) && options[:resources].include?(default_r)
    # Return default topic unless specified
    @comm.stubs(:create_topic).returns(@topics[default_r])
  end
  options[:resources].each do |t_name|
    @topics[t_name].stubs(:address).returns("xmpp://localhost/#{t_name.to_s}")
    @comm.stubs(:create_topic).with("xmpp://localhost/#{t_name}").returns(@topics[t_name])
  end
end

def unmock_comm_in_res_proxy
  @comm.class_eval do
    undef_method(:subscribe)
  end
  OmfCommon.unstub(:comm)
  [:inform, :publish, :unsubscribe].each do |m_name|
    OmfCommon::Comm::Topic.any_instance.unstub(m_name)
  end
end

OmfCommon::Message.init(type: :xml)

