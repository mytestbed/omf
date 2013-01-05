require 'active_support/core_ext'
require 'omf_common/default_logging'
require 'omf_common/version'
require 'omf_common/measure'
require 'omf_common/message'
require 'omf_common/comm'
require 'omf_common/command'
require 'omf_common/topic'
require 'omf_common/topic_message'
require 'omf_common/key'
require 'omf_common/core_ext/string'
require 'omf_common/core_ext/object'

include OmfCommon::DefaultLogging

module OmfCommon
  #
  # Initialize the OMF runtime.
  # Options are:
  #    :communication
  #      :type 
  #      ... specific opts
  #
  # @param [Hash] opts
  #
  def self.init(opts = {})
    unless copts = opts[:communication]
      raise "Missing :communication description"
    end
    EM.run do
      Comm.init(copts)
      trap(:INT) { comm.disconnect }
      trap(:TERM) { comm.disconnect }
    end    
    
  end
  
  # Return the communication driver instance
  #
  def self.comm()
    Comm.instance
  end
end
