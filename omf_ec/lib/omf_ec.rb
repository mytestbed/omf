# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require "omf_common"
require 'omf_ec/core_ext/hash'
require 'omf_ec/backward/dsl'
require 'omf_ec/backward/group'
require 'omf_ec/backward/app_definition'
require 'omf_ec/backward/default_events'
require 'omf_ec/backward/core_ext/array'
require "omf_ec/version"
require "omf_ec/experiment_property"
require "omf_ec/experiment"
require "omf_ec/group"
require "omf_ec/app_definition"
require "omf_ec/context"
require "omf_ec/graph"
require "omf_ec/prototype"
require "omf_ec/dsl"

module OmfEc

  # OML Measurement Point (MP)
  # This MP is for measurements about messages received by the Resource Proxy
  class OmfEc::MPReceived < OML4R::MPBase
    name :ec_received
    param :time, :type => :double # Time (s) when this message was received
    param :topic, :type => :string # Pubsub topic where this message came from
    param :mid, :type => :string # Unique ID this message
  end

  class << self
    # Experiment instance
    #
    # @return [OmfEc::Experiment]
    def experiment
      Experiment.instance
    end

    alias_method :exp, :experiment

    # Full path of lib directory
    def lib_root
      File.expand_path("../..", "#{__FILE__}/lib")
    end

    def register_default_callback(topic)
      topic.on_inform do |msg|
        OmfEc::MPReceived.inject(Time.now.to_f, topic.id, msg.mid) if OmfCommon::Measure.enabled?
        case msg.itype.upcase
        when 'CREATION.FAILED'
          warn "RC reports creation.failed: '#{msg[:reason]}'", msg.src
          debug msg, msg.src
        when 'ERROR'
          warn "RC reports error: '#{msg[:reason]}'", msg.src
          debug msg, msg.src
        when 'WARN'
          warn "RC reports warning: '#{msg[:reason]}'", msg.src
          debug msg, msg.src
        when 'CREATION.OK'
          debug "Resource #{msg[:res_id]} #{msg.resource.address} created"
          debug "Received CREATION.OK via #{topic.id}"
          debug msg, msg.src

          OmfEc.experiment.add_or_update_resource_state(msg.resource.address, msg.properties)
          OmfEc.experiment.process_events
        when 'STATUS'
          props = []
          msg.each_property { |k, v| props << "#{k}: #{v}" }
          debug "Received INFORM via #{topic.id} >> #{props.join(", ")}", msg.src

          if msg[:status_type] == 'APP_EVENT'
            info "APP_EVENT #{msg[:event]} from app #{msg[:app]} - msg: #{msg[:msg]}"
          end

          OmfEc.experiment.add_or_update_resource_state(msg.src, msg.properties)
          OmfEc.experiment.process_events
        end
      end
    end

    #TODO: Could we find a better name for this method?
    def subscribe_and_monitor(topic_id, context_obj = nil, &block)
      topic = OmfCommon::Comm::Topic[topic_id]
      if topic.nil?
        OmfCommon.comm.subscribe(topic_id) do |topic|
          if topic.error?
            error "Failed to subscribe #{topic_id}"
          else
            debug "Subscribed to #{topic_id}"
            context_obj.associate_topic(topic) if context_obj
            block.call(context_obj || topic) if block
            register_default_callback(topic)
          end
        end
      else
        context_obj.associate_topic(topic) if context_obj
        block.call(context_obj || topic) if block
      end
    end
  end
end

include OmfEc::DSL
include OmfEc::Backward::DSL
include OmfEc::Backward::DefaultEvents

Experiment = OmfEc::Experiment
