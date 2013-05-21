# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'hashie'
require 'singleton'

module OmfEc
  #
  # This class defines an Experiment Property, and also holds all of the
  # Experiment Properties defined for a given experiment.
  # Most of this implementation is re-used from OMF 5.4
  #
  class ExperimentProperty

    # Contains all the experiment properties
    @@properties = Hashie::Mash.new

    # Holds all observers on any Experiment Property creation
    @@creation_observers = []

    #
    # Returns a given property
    # - name =nameof the property to return
    #
    # [Return] a property
    #
    def self.[](name)
      p = @@properties[name.to_s.to_sym]
      if p.nil?
        raise OEDLCommandException.new(name,
          "Unknown experiment property '#{name}'\n\tKnown properties are "+
          "'#{ExperimentProperty.names.join(', ')}'")
      end
      return p
    end

    def self.[]=(name, val)
      p = ExperimentProperty[name.to_sym]
      p.set(val)
    end

    def self.length; @@properties.length end

    # Minitest needs to be able to turn this Class into a string, this is
    # normally done through the default 'method_missing' of the Classe
    # but we redefined that... so to run minitest we need to explicitly
    # define 'to_str' for this Class
    def self.to_str; "ExperimentProperty" end

    #
    # Handles missing method, allows to access an existing Experiment
    # Property with the syntax 'propcontext.propname'
    #
    def self.method_missing(name, args = nil)
      name = name.to_s
      if setter = (name[-1] == ?=)
        name.chop!
      end
      p = ExperimentProperty[name.to_sym]
      if setter
        p.set(args)
      else
        return p
      end
    end

    # Iterate over all Experiment Properties. The block
    # will be called with the respective property as single
    # argument
    #
    # - sort_names = if 'true' sort the properties (default: true)
    # - &block = the block of commands to call
    #
    def self.each(sort_names = false, &block)
      names = @@properties.keys
      names = names.sort_by {|sym| sym.to_s} if (sort_names)
      names.each { |n| block.call(@@properties[n]) }
    end

    # Return an existing Experiment Property, or create a new one
    #
    # - name = name of the property to create/return
    # - value = value to assign to this property
    # - description = short string description for this property
    #
    # [Return] an Experiment Property
    #
    def self.create(name, value = nil, description = nil)
      name = name.to_s
      # http://stackoverflow.com/questions/4378670/what-is-a-ruby-regex-to-match-a-function-name
      if /[@$"]/ =~ name.to_sym.inspect
        raise OEDLCommandException.new("ExperimentProperty.create",
          "Cannot create property '#{name}', its name is not a valid Ruby name")
      end
      p = nil
      name = name.to_sym
      if (p = @@properties[name]) != nil
        p.set(value) if value != nil
        p.description = description if description != nil
      else
        p = ExperimentProperty.new(name, value, description)
        @@properties[name] = p
        # Let the observers know that we created a new property
        @@creation_observers.each { |proc| proc.call(:create, p) }
      end
      return p
    end

    #
    # Return the names of the all defined Experiment Properties
    #
    # [Return] an Array with the names of all defined Experiment Properties
    #
    def self.names() return @@properties.keys end

    # Add an observer for any creation of a new Experiment Property
    #
    # - proc = block to execute when a new Experiment Property is created
    #
    def self.add_observer(&proc) @@creation_observers << proc end

    attr_reader :name, :value, :id
    attr_accessor :description

    private :initialize

    #
    # Create a new Experiment Property
    #
    # - name = name of the property to create/return
    # - value = value to assign to this property
    # - description = short string description for this property
    #
    def initialize(name, value = nil, description = nil)
      @name = name.to_s
      @description = description
      @change_observers = Array.new
      set(value)
    end

    #
    # Add a block of command to the list of actions to do
    # when this property is being changed
    #
    # - &block =  the block of command to add
    #
    def on_change (&block)
      debug "Somebody bound to me"
      @change_observers << block
    end

    #
    # Update the value of this Experiment Property
    #
    # - value = new value for this property
    #
    def set(value)
      @value = value
      info "#{name} = #{value.inspect} (#{value.class})"
      @change_observers.each { |proc| proc.call(value) }
    end

    # Implicit conversion to String (required for + operator)
    def to_str() @value.to_s end

    # Explicit conversion to String
    alias_method :to_s, :to_str

    # Division operator for Integer and Float properties
    def /(right)
      if @value.kind_of?(Integer) || @value.kind_of?(Float)
        return (@value / right)
      else
        raise OEDLCommandException.new("/", "Illegal operation, "+
          "the value of Experiment Property '#{@name}' is not numerical "+
          "(current value is of type #{value.class})")
      end
    end

    # Multiplication operator for Integer and Float properties
    def *(right)
      if @value.kind_of?(Integer) || @value.kind_of?(Float)
        return (@value * right)
      else
        raise OEDLCommandException.new("*", "Illegal operation, "+
          "the value of Experiment Property '#{@name}' is not numerical "+
          "(current value is of type #{value.class})")
      end
    end

    # Substraction operator for Integer and Float properties
    def -(right)
      if @value.kind_of?(Integer) || @value.kind_of?(Float)
        return (@value - right)
      else
        raise OEDLCommandException.new("-", "Illegal operation, "+
          "the value of Experiment Property '#{@name}' is not numerical "+
          "(current value is of type #{value.class})")
      end
    end

    # Addition operator for Integer, Float, and String properties
    def +(right)
      if @value.kind_of?(Integer) || @value.kind_of?(Float) || @value.kind_of?(String)
        return (@value + right)
      else
        raise OEDLCommandException.new("+", "Illegal operation, "+
          "The value of Experiment Property '#{@name}' does not support addition "+
          "(current value is of type #{value.class})")
      end
    end

    # Explicit Coercion for Integer, Float, and String properties
    # (allow property to be on the right-hand of an operator such as +)
    def coerce(other)
      if @value.kind_of?(Integer) || @value.kind_of?(Float) || @value.kind_of?(String)
        return other, @value
      else
        raise OEDLCommandException.new("coercion", "Illegal operation, "+
          "The value of Experiment Property '#{@name}' cannot be coerced to allow "+
          " the requested operation (current value is of type #{value.class})")
      end
    end
  end
end
