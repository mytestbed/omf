#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#
# = prototype.rb
#
# == Description
#
# This file defines the 'Prototype' classe
#
require "omf-expctl/version.rb"
require "omf-expctl/parameter.rb"
require "omf-expctl/application/application.rb"
#require "omf-expctl/oml/oml_mpoint.rb"
require "rexml/document"

#
# This class describes a prototype which can be used to access applications within an Experiment.
#
class Prototype

  @@prototypes = Hash.new
  @@bindStruct = Struct.new(:name)

  #
  # Return a known Prototype instance.
  #
  # [Return] the uri 'URI' identifying the Prototype
  #
  def self.[](uri)
    proto = @@prototypes[uri]
    if proto == nil
      MObject.debug('Prototype: ', 'Loading prototype "', uri, '".')
      str, type = OConfig.load(uri, true)
      #MObject.debug('Prototype: ', 'str: "', str, '".')
      if type == "text/xml"
        # proto = Prototype.from_xml(str.to_xml???)
      elsif type == "text/ruby"
        # 'str' has already been evaluated
        proto = @@prototypes[uri]
      end
      if proto == nil
        raise "Unknown prototype '#{uri}'."
      end
    end
    return proto
  end

  #
  # Create a new Prototype instance.
  #
  # - uri = an URI identifying the new Prototype
  # - name = an optional name for this Prototype (default = 'uri')
  #
  def self.create(uri, name = uri)
    return Prototype.new(uri, name)
  end
  
  #
  # Reset all class state. Specifically forget all prototype declarations.
  # This is primarily used by the test suite.
  #
  def self.reset()
    @@prototypes = Hash.new
    @@bindStruct = Struct.new(:name)
  end

  # Global reference
  attr_writer :uri

  # Name of prototype
  attr_writer :name

  # Version of prototype
  attr_reader :version

  # Description of the prototype
  attr_writer :description

  # Parameters of the prototype
  attr_reader :parameters

  # Applications used on the prototype
  attr_reader :applications

  #
  # Create a new Prototype instance.
  #
  # - uri = an URI identifying the new Prototype
  # - name = an optional name for this Prototype (default = 'uri')
  #
  def initialize(uri, name = uri)
    if @@prototypes.has_key? uri
      raise "prototype with name '" + uri + "' already exists."
    end
    @@prototypes[uri] = self

    @uri = uri
    @name = name
    @properties = Hash.new
    @incPrototypes = Hash.new
    @applications = Array.new
  end

  #
  # Instantiate this prototype for a particular node set.
  #
  # - nodeSet = NodeSet to configure according to this prototype
  # - bindings = a Hash with the bindings for local parameters
  #
  def instantiate(nodeSet, bindings)
    if bindings == nil : bindings = Hash.new end
    # check if bindings contain unknown properties
    if (diff = bindings.keys - @properties.keys) != []
      raise "Unknown parameters '#{diff.join(', ')}'" \
      + " not in '#{@properties.keys.join(', ')}'."
    end
    # merge bindings with properties declaration
    context = Hash.new
    @properties.each {|name, param|
      #puts "A>> #{name}"
      context[name] = getBoundValue(name, bindings)
    }
    @incPrototypes.each {|name, params|
      proto = Prototype[name]
      p = params.clone
      p.each { |key, val|
        if val.kind_of?(@@bindStruct)
          #puts "B>> #{val.name}:#{key}"
          p[key] = val = getBoundValue(val.name, bindings)
        end
        #debug "recursive bindings: #{key}=>#{val}"
      }
      proto.instantiate(nodeSet, p)
    }

    @applications.each {|app|
      app.instantiate(nodeSet, context)
    }
  end

  #
  # Return the value of a given property 'name' within the
  # context of 'bindings'.
  #
  # - name = name of the property to get the value from 
  # - bindings = context for this property
  #
  # [Return] The value of the property
  #
  def getBoundValue(name, bindings)
    if (bindings.has_key? name)
      return bindings[name]
    else
      # use default
      if (@properties[name] == nil)
        raise "Unknown property #{name}"
      end
      if (default = @properties[name].defaultValue) == nil
        raise "Property #{name} is required"
      end
      return default
    end
  end
  private :getBoundValue

  #
  # Return the definition of this Prototype as a XML element
  #
  # [Return] a XML element with the definition of this Prototype
  #
  def to_xml
    a = REXML::Element.new("prototype")
    a.add_attribute("id", @uri)
    a.add_element("name").text = name != nil ? name : uri

    if (version != nil)
      a.add_element(version.to_xml)
    end
    a.add_element("description").text = description

    if @properties.length > 0
      pe = a.add_element("properties")
      @properties.each_value {|p|
        pe.add_element(p.to_xml)
      }
    end

    if @incProperties.length > 0
      ie = a.add_element("properties")
      ie.text = NOT_IMPLEMENTED
    end

    if @applications.length > 0
      ae = a.add_element("applications")
      @applications.each {|app|
        ae.add_element(app.to_xml)
      }
    end
    return a
  end

  #
  # Define a property for this prototype
  #
  # - id = ID of parameter, also used as name
  # - description = Description of parameter's purpose
  # - default = Default value if not set, makes parameter optional
  #
  def defProperty(id, description, default = nil)
    if @properties[id] != nil
      raise "Property '" + id + "' already defined."
    end
    param = Parameter.new(id, id, description, default)
    @properties[id] = param
  end

  #
  # Returns an object which maintains the connection to a
  # a local property of this Prototype.
  #
  # - name = name of the local property
  # 
  # [Return] a structure with connection info to the local property
  #
  def bindProperty(name)
      @@bindStruct.new(name)
  end

  #
  # Set the version number for this Prototype
  #
  # - major = major version number
  # - minor = minor version number
  # - revision = revision version number
  #
  def setVersion(major = 0, minor = 0, revision = 0)
    @currentVersion = MutableVersion.new(major, minor, revision)
  end

  #
  # Add a nested Prototype which should be instantiated when
  # this Prototype is instantiated.
  #
  # - name = Name used for reference
  # - param = Hash of parameter bindings
  #
  def addPrototype(name, param)
     if @incPrototypes.has_key? name
       raise "Prototype already has a prototype '" + name + "'."
     end
    @incPrototypes[name] = param
  end

  #
  # Add an Application which should be installed on this prototype.
  #
  # - idRef = URI of application to add
  # - opts = Optional options, see +Application#initialize+
  #
  # [Return] The newly create application object
  #
  def addApplication(idRef, opts = {}, &block)

    #if @applications.has_key? idRef
    #  raise "Prototype already has an application '" + name + "'."
    #end
    app = Application.new(idRef, opts, &block)
    @applications << app
    return app
  end

end
