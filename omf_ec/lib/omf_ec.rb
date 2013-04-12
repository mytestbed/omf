require "omf_common"
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
require "omf_ec/dsl"

module OmfEc
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
      topic.on_creation_failed do |msg|
        warn "RC reports creation.failed: '#{msg[:reason]}'"
        debug msg
      end

      topic.on_error do |msg|
        warn "RC reports error: '#{msg[:reason]}'"
        debug msg
      end

      topic.on_warn do |msg|
        warn "RC reports warning: '#{msg[:reason]}'"
        debug msg
      end

      topic.on_creation_ok do |msg|
        debug "Received CREATION.OK via #{topic.id}"
        info "Resource #{msg[:res_id]} #{msg.resource.address} created"

        OmfEc.experiment.add_or_update_resource_state(msg.resource.address, msg.properties)

        OmfEc.experiment.process_events
      end

      topic.on_status do |msg|
        props = []
        msg.each_property { |k, v| props << "#{k}: #{v}" }
        debug "#{topic.id} >> inform: #{props.join(", ")}"

        if msg[:status_type] == 'APP_EVENT'
          info "APP_EVENT #{msg[:event]} from app #{msg[:app]} - msg: #{msg[:msg]}"
        end

        OmfEc.experiment.add_or_update_resource_state(msg.src, msg.properties)
        OmfEc.experiment.process_events
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
            info "Subscribed to #{topic_id}"
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
