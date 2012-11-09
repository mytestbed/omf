require 'active_support/core_ext'
require 'eventmachine'

# DSL methods to be used for OEDL scripts
#
module OmfEc
  module DSL
    # Experiment instance
    def experiment
      Experiment.instance
    end

    alias_method :exp, :experiment

    # Experiment's communicator instance
    def communicator
      exp.comm
    end

    alias_method :comm, :communicator

    # Use EM timer to execute after certain time
    #
    # @example do something after 2 seconds
    #
    #   after 2.seconds { 'do something' }
    def after(time, &block)
      comm.add_timer(time, block)
    end

    def every(time, &block)
      comm.add_periodic_timer(time, block)
    end

    def def_group(name, *members, &block)
      comm.subscribe(name, create_if_non_existent: true) do |m|
        unless m.error?
          group = Group.new(name)
          exp.groups << group
          if block
            block.call group
          else
            members.each do |m|
              group.add_resource(m)
            end
          end
        end
      end
    end

    def group(name, &block)
      group = exp.groups.find {|v| v.name == name}
      block.call(group) if block
      group
    end

    def all_groups(&block)
      group(exp.id, &block)
    end

    # Exit the experiment
    def done!
      Experiment.done
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
      exp.property[name] ||= default_value
    end

    # Return the context for setting experiment wide properties
    def property
      Experiment.instance.property
    end

    alias_method :prop, :property

    def resource(resName)
      res = OMF::EC::Node[resName]
      return res
    end

    # Evalute block over all nodes in an the experiment, even those
    # that do not belong to any groups
    #
    # - &block = the code-block to evaluate/execute on all the nodes
    #
    # [Return] a RootNodeSetPath object referring to all the nodes
    #
    def all_nodes!(&block)
      NodeSet.freeze
      ns = RootGroupNodeSet.instance
      return RootNodeSetPath.new(ns, nil, nil, block)
    end

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

    def def_event(name, &trigger)
      if exp.events.find { |v| v[:name] == name }
        raise RuntimeError, "Event '#{name}' has been defined"
      else
        exp.events << { name: name, trigger: trigger }
      end
    end

    def on_event(name, consume_event = true, &callback)
      event = exp.events.find { |v| v[:name] == name }
      if event.nil?
        raise RuntimeError, "Event '#{name}' not defined"
      else
        event[:callback] = callback
        event[:consume_event] = consume_event
      end
    end

    # Wait for some time before issuing more commands
    #
    # - duration = Time to wait in seconds (can be
    #
    def wait(duration)
      warn "Wait will pause the entire event system, so I won't do it. Please use after instead."
    end

    include OmfEc::BackwardDSL
  end
end
