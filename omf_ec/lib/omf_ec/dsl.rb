# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'active_support'
require 'active_support/deprecation'
require 'active_support/core_ext'
require 'eventmachine'

module OmfEc
  # DSL methods to be used for OEDL scripts
  module DSL

    # Define OEDL-specific exceptions. These are the Exceptions that might be
    # raised when the OMF EC is processing an OEDL experiment scripts
    #
    # The base exception is OEDLException
    class OEDLException < StandardError; end

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

    def def_application(name, &block)
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
    # @param type of property
    #
    def def_property(name, default_value, description = nil, type = nil)
      OmfEc.experiment.add_property(name, default_value, description)
    end

    # Return the context for setting experiment wide properties
    def property
      return OmfEc.experiment.property
    end

    # Check if a property exist, if not then define it
    # Take the same parameter as def_property
    #
    def ensure_property(name, default_value, description = nil, type = nil)
      begin 
        property[name]
      rescue
        def_property(name, default_value, description, type)
      end
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
      !array.any? ? false : array.any? { |v| v.to_s == value.to_s }
    end

    # Define an event
    def def_event(name, &trigger)
      raise ArgumentError, 'Need a trigger callback' if trigger.nil?
      OmfEc.experiment.add_event(name, trigger)
    end

    # Create an alias name of an event
    def alias_event(new_name, name)
      unless (event = OmfEc.experiment.event(name))
        raise RuntimeError, "Can not create alias for Event '#{name}' which is not defined"
      else
        event[:aliases] << new_name
      end
    end

    # Define an event callback
    def on_event(name, consume_event = true, &callback)
      unless (event = OmfEc.experiment.event(name))
        raise RuntimeError, "Event '#{name}' not defined"
      else
        event[:callbacks] ||= []
        event[:callbacks] << callback
        event[:consume_event] = consume_event
      end
    end

    # Define a new graph widget showing experiment related measurements to be
    # be used in a LabWiki column.
    #
    # The block is called with an instance of the 'LabWiki::OMFBridge::GraphDescription'
    # class. See that classes' documentation on the methods supported.
    #
    # @param name short/easy to remember name for this graph
    def def_graph(name = nil, &block)
      if OmfEc.experiment.show_graph
        gd = OmfEc::Graph::GraphDescription.create(name)
        block.call(gd)
        gd._report
      end
    end

    # Load an additional OEDL script 
    #
    # First try to load the script from the paths associated to this running 
    # Ruby instance. This would allow the loading of scripts shipped with 
    # the EC gem. If that fails, then look for the script in the local file
    # system or at the given web URL.
    #
    # If an optional has of key/value is provided, then define an OMF
    # Experiment Property for each keys and assigne them the values.
    #
    # @param location name, path or URL for the OEDL script to load
    # @param opts optional hash of key/values for extra Experiment Property to define
    #
    def load_oedl(location, opts = {})
      # Define the additional properties from opts
      opts.each { |k,v| def_property(k, v,) } 
      # Try to load OEDL Library as built-in then external
      begin
        require location
        info "Loaded built-in OEDL library '#{location}'"
      rescue LoadError
        begin
          require 'open-uri'
          require 'tempfile'
          file = Tempfile.new("oedl-#{Time.now.to_i}")
          open(location) { |io| file.write(io.read) }
          file.close
          load(file.path) 
          file.unlink
          info "Loaded external OEDL library '#{location}'"
        rescue Exception => e
          error "Fail loading external OEDL library '#{location}': #{e}"
        end
      rescue Exception => e 
        error "Fail loading built-in OEDL library '#{location}': #{e}"
      end
    end

  end
end
