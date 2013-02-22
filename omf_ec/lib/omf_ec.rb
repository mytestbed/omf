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

    def subscribe_and_monitor(topic_id, context_obj = nil, &block)
      OmfCommon.comm.subscribe(topic_id) do |res|
        unless res.error?
          context_obj.associate_topic(res) if context_obj

          block.call(context_obj || res) if block

          res.on_creation_failed do |msg|
            debug msg
            warn "RC reports failure: '#{msg[:reason]}'"
          end

          res.on_creation_ok do |msg|
            info "Resource #{msg[:resource_id]} created"
            OmfEc.experiment.add_resource(msg[:resource_id],
                                          type: msg[:type],
                                          hrn: msg[:hrn],
                                          membership: msg[:membership])

            OmfEc.experiment.process_events
          end

          res.on_status do |msg|
            msg.each_property { |k, v| debug "#{k} > #{v}" }

            resource = OmfEc.experiment.resource(msg[:uid])

            if resource.nil?
              OmfEc.experiment.add_resource(msg[:uid],
                                            type: msg[:type],
                                            hrn: msg[:hrn],
                                            membership: msg[:membership])
            else
              if msg[:status_type] == 'APP_EVENT'
                info "APP_EVENT #{msg[:event]} from app #{msg[:app]} - msg: #{msg[:msg]}"
              end
              msg.each_property { |key, value| resource[key] = value }
            end

            OmfEc.experiment.process_events
          end
        end
      end
    end
  end
end
