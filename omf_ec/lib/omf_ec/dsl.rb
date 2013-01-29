require 'active_support/core_ext'
require 'eventmachine'

module OmfEc
  # DSL methods to be used for OEDL scripts
  module DSL
    # Use EM timer to execute after certain time
    #
    # @example do something after 2 seconds
    #
    #   after 2.seconds { 'do something' }
    def after(time, &block)
      OmfCommon.eventloop.after(time, block)
    end

    # Use EM periodic timer to execute after certain time
    #
    # @example do something every 2 seconds
    #
    #   every 2.seconds { 'do something' }
    def every(time, &block)
      OmfCommon.eventloop.every(time, block)
    end

    def def_application(name,&block)
      app_def = OmfEc::AppDefinition.new(name)
      OmfEc.exp.app_definitions[name] = app_def
      block.call(app_def) if block
    end

    # Define a group, create a pubsub topic for the group
    #
    # @param [String] name name of the group
    #
    # @example add resource 'a' to group 'bob'
    #   def_group('bob') do |g|
    #     g.add_resource('a')
    #   end
    #
    # @see OmfEc::Backward::DSL#defGroup
    def def_group(name, &block)
      group = OmfEc::Group.new(name)
      OmfEc.exp.groups << group

      OmfEc.comm.subscribe(group.id, create_if_non_existent: true) do |m|
        unless m.error?
          block.call group if block

          rg = OmfEc.comm.get_topic(group.id)

          rg.on_message lambda {|m| m.operation == :inform && m.read_content('inform_type') == 'CREATION_FAILED' && m.context_id.nil? } do |i|
            warn "RC reports failure: '#{i.read_content("reason")}'"
          end

          rg.on_message lambda {|m| m.operation == :inform && m.read_content('inform_type') == 'STATUS' && m.context_id.nil? } do |i|
            r = OmfEc.exp.state.find { |v| v[:uid] == i.read_property(:uid) }
            unless r.nil?
              i.each_property do |p|
                key = p.attr('key').to_sym
                r[key] = i.read_property(key)
              end
            end
            Experiment.instance.process_events
          end
        end
      end
    end

    # Get a group instance
    #
    # @param [String] name name of the group
    def group(name, &block)
      group = OmfEc.exp.groups.find {|v| v.name == name}
      block.call(group) if block
      group
    end

    # Iterator for all defined groups
    def all_groups(&block)
      OmfEc.exp.groups.each do |g|
        block.call(g) if block
      end
    end

    alias_method :all_nodes!, :all_groups

    # Exit the experiment
    #
    # @see OmfEc::Experiment.done
    def done!
      OmfEc::Experiment.done
    end

    alias_method :done, :done!

    # Define an experiment property which can be used to bind
    # to application and other properties. Changing an experiment
    # property should also change the bound properties, or trigger
    # commands to change them.
    #
    # @param name of property
    # @param default_value for this property
    # @param description short text description of this property
    #
    def def_property(name, default_value, description = nil)
      OmfEc.exp.property[name] ||= default_value
    end

    # Return the context for setting experiment wide properties
    def property
      OmfEc.exp.property
    end

    alias_method :prop, :property

    # Check if all elements in array equal the value provided
    #
    def all_equal(array, value = nil, &block)
      if array.empty?
        false
      else
        if value
          array.all? { |v| v.to_s == value.to_s }
        else
          array.all?(&block)
        end
      end
    end

    # Check if any elements in array equals the value provided
    #
    def one_equal(array, value)
      array.any? ? false : array.all? { |v| v.to_s == value.to_s }
    end

    # Define an event
    def def_event(name, &trigger)
      if OmfEc.exp.events.find { |v| v[:name] == name }
        raise RuntimeError, "Event '#{name}' has been defined"
      else
        OmfEc.exp.events << { name: name, trigger: trigger }
      end
    end

    # Define an event callback
    def on_event(name, consume_event = true, &callback)
      event = OmfEc.exp.events.find { |v| v[:name] == name }
      if event.nil?
        raise RuntimeError, "Event '#{name}' not defined"
      else
        event[:callbacks] ||= []
        event[:callbacks] << callback
        event[:consume_event] = consume_event
      end
    end

    include OmfEc::Backward::DSL
  end
end
