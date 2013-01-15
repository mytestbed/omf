require 'active_support/core_ext'
require 'omf_common/default_logging'
require 'omf_common/version'
require 'omf_common/measure'
require 'omf_common/message'
require 'omf_common/comm'
require 'omf_common/command'
# require 'omf_common/topic'
# require 'omf_common/topic_message'
require 'omf_common/key'
require 'omf_common/core_ext/string'
require 'omf_common/core_ext/object'
require 'omf_common/eventloop'

include OmfCommon::DefaultLogging

module OmfCommon
  DEF_RUNTIME_OPTS = {type: :em}
  
  #
  # Initialize the OMF runtime.
  # Options are:
  #    :communication
  #      :type 
  #      ... specific opts
  #    :eventloop
  #      :type {:em|:local...}
  #
  # @param [Hash] opts
  #
  def self.init(opts = {}, &block)
    unless copts = opts[:communication]
      raise "Missing :communication description"
    end
    ropts = (opts[:runtime] || DEF_RUNTIME_OPTS)
    Eventloop.init(ropts) do
      Comm.init(copts)
      block.call if block
    end    
  end
  
  # Return the communication driver instance
  #
  def self.comm()
    Comm.instance
  end
  
  # Return the communication driver instance
  #
  def self.eventloop()
    Eventloop.instance
  end
  
end
