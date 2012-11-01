require 'active_support/core_ext'
require 'eventmachine'

# DSL methods to be used for OEDL scripts
#
module OmfEc
  module DSL
    # Adding all top level resources to this
    GLOBAL_GROUP = 'universe'

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

    def def_group(name, members = [], &block)
      comm.subscribe(name, true) do |m|
        unless m.error?
          group = Group.new(name)
          exp.groups << group
          block.call group
        end
      end
    end

    alias_method :defGroup, :def_group

    def group(name, &block)
      group = exp.groups.find {|v| v.name == name}
      block.call(group)
    end

    # Exit the experiment
    def done!
      comm.disconnect
    end

    alias_method :done, :done!

    # Define an experiment property which can be used to bind
    # to application and other properties. Changing an experiment
    # property should also change the bound properties, or trigger
    # commands to change them.
    #
    # - name = name of property
    # - defaultValue = default value for this property
    # - description = short text description of this property
    #
    def def_property(name, default_value, description = nil)
      exp.property[name] = default_value
    end

    alias_method :defProperty, :def_property

    # Return the context for setting experiment wide properties
    #
    # [Return] a Property Context
    #
    def property
      Experiment.instance.property
    end

    alias_method :prop, :property

    def resource(resName)
      res = OMF::EC::Node[resName]
      return res
    end

    # Evaluate a code-block over all nodes in all groups of the experiment.
    #
    # - &block = the code-block to evaluate/execute on all the groups of nodes
    #
    # [Return] a RootNodeSetPath object referring to all the groups of nodes
    #
    def all_groups(&block)
      NodeSet.freeze
      ns = DefinedGroupNodeSet.instance
      return RootNodeSetPath.new(ns, nil, nil, block)
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

    alias_method :allEqual, :all_equal

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

    alias_method :defEvent, :def_event

    def on_event(name, consume_event = true, &callback)
      event = exp.events.find { |v| v[:name] == name }
      if event.nil?
        raise RuntimeError, "Event '#{name}' not defined"
      else
        event[:callback] = callback
        event[:consume_event] = consume_event
      end
    end

    alias_method :onEvent, :on_event

    # Wait for some time before issuing more commands
    #
    # - duration = Time to wait in seconds (can be
    #
    def wait(duration)
      warn "Wait will pause the entire event system, so I won't do it. Please use after instead."
    end
  end
end
