require 'active_support/core_ext'
require 'eventmachine'

module OmfEc
  # DSL methods to be used for OEDL scripts
  module DSL

    # Define OEDL-specific exceptions. These are the Exceptions that might be
    # raised when the OMF EC is processing an OEDL experiment scripts
    #
    # The base exception is OEDLException
    class OEDLException < Exception; end

    class OEDLArgumentException < OEDLException
      attr_reader :cmd, :arg
      def initialize(cmd, arg, msg = nil)
        @cmd = cmd
        @arg = arg
        msg ||= "Illegal value for argument '#{arg}' in command '#{cmd}'"
        super(msg)
      end
    end

    class OEDLCommandException < OEDLException
      attr_reader :cmd
      def initialize(cmd, msg = nil)
        @cmd = cmd
        msg ||= "Illegal command '#{cmd}' unsupported by OEDL"
        super(msg)
      end
    end

    class OEDLUnknownProperty < OEDLException
      attr_reader :cmd
      def initialize(name, msg = nil)
        @name = name
        msg ||= "Unknown property '#{name}', not previously defined in your OEDL experiment"
        super(msg)
      end
    end


    # Use EM timer to execute after certain time
    #
    # @example do something after 2 seconds
    #
    #   after 2.seconds { 'do something' }
    def after(time, &block)
      OmfCommon.eventloop.after(time, &block)
    end

    # Use EM periodic timer to execute after certain time
    #
    # @example do something every 2 seconds
    #
    #   every 2.seconds { 'do something' }
    def every(time, &block)
      OmfCommon.eventloop.every(time, &block)
    end

    def def_application(name,&block)
      app_def = OmfEc::AppDefinition.new(name)
      OmfEc.experiment.app_definitions[name] = app_def
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
      group = OmfEc::Group.new(name, &block)
      OmfEc.experiment.add_group(group)
      group
    end

    # Get a group instance
    #
    # @param [String] name name of the group
    def group(name, &block)
      group = OmfEc.experiment.group(name)
      raise RuntimeError, "Group #{name} not found" if group.nil?

      block.call(group) if block
      group
    end

    # Iterator for all defined groups
    def all_groups(&block)
      OmfEc.experiment.each_group(&block)
    end

    def all_groups?(&block)
      OmfEc.experiment.all_groups?(&block)
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
      OmfEc.experiment.add_property(name, default_value, description)
    end

    # Return the context for setting experiment wide properties
    def property
      return OmfEc.experiment.property
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
      raise ArgumentError, 'Need a trigger callback' if trigger.nil?
      OmfEc.experiment.add_event(name, trigger)
    end

    # Define an event callback
    def on_event(name, consume_event = true, &callback)
      event = OmfEc.experiment.event(name)
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
