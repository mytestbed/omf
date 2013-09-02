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
# = property.rb
#
# == Description
#
# This file defines the 'Property' classe
#

#
# This class describes a Property, which is part of a Prototype
#
class Property

  #
  # Unmarshall a Property instance from an XML tree.
  #
  # - defRoot = the root of the XML tree describing the Property
  #
  # [Return] a new Property instance initialized with the information from the XML tree
  #
  def Property.from_xml(defRoot)
    if (defRoot.name != "property")
      raise "Property definition needs to start with an 'property' element"
    end
    idref = defRoot.attributes['idref']
    obj = unit = nil
    isBinding = false
    defRoot.elements.each { |el|
      case el.name
      when 'binding'
        obj = el.attribute['idref']
        isBinding = true
      when 'value'
        obj = el.text
        unit = el.attribute['unit']
      else
        warn "Ignoring element '#{el.name}'"
      end
    }
    if isBinding then warn "NOT IMPLEMENTED: Resolving bindings from XML streams" end
    p = Property.new(idred, obj, unit, isBinding)
    return p
  end

  attr_reader :idref, :value, :unit, :bindingRef, :isBound

  #
  # Create a new Property instance
  #
  # - idref = Reference to property in {@link AppDefinition}
  # - obj = Value or property binding to establish value of property
  # - unit = Unit of value
  # - isBinding = If true "obj" is a property reference, otherwise it's a value
  #
  def initialize(idref, obj = nil, unit = nil, isBinding = false)
    @idref = idref
    @unit = unit
    if isBinding
      @bindingRef = obj
    else
      @value = obj
    end
    @isBound = isBinding
  end

  #
  # Return the definition of this Property as an XML element
  #
  # [Return] a XML element describing this Property
  #
  def to_xml
    a = REXML::Element.new("property")
    a.add_attribute("name", idref)
    if isBound
      a.add_element("binding", {"idref" => bindingRef})
    elsif value != nil
      v = a.add_element("value")
      v.text = value
      if (unit != nil)
        v.add_attribute("unit", unit)
      end
    else
      Log.warn("NOT IMPLEMENTED: check for default value in app definition")
    end
    return a
  end

end

#
# This module defines the methods used to create new Properties when defining Prototypes/Applications in Experiments
#
module CreatePropertiesModule

  #
  # Set a property of the application to a specific value
  #
  # - propName = Name of the application property
  # - value = Value of property
  # - unit = optional, unit for this Property
  #
  def setProperty(propName, value, unit = nil)
    prop = Property.new(propName, value, unit)
    @properties += [prop]
  end

  #
  # Bind the value of a property to another property in the context
  #
  # - propName = name of application property
  # - propRef = Property to bind to (default = 'propName')
  #
  def bindProperty(propName, propRef = propName)
    prop = Property.new(propName, propRef, nil, true)
    @properties += [prop]
  end

  #
  # Add a list of properties described in a hash table
  # where key is the property name and the value its value.
  # If value starts with "$", value is interpreted as
  # the name of another property to bind to.
  #
  # - properties = a Hash describing a set of properties
  #
  def addProperties(properties)
    if properties != nil
      if properties.kind_of?(Hash)
        properties.each {|k, v|
          if v.kind_of?(Symbol)
            v = v.to_s
          end
          if v.kind_of?(String) && v[0] == ?$
            # is binding
            bindProperty(k, v[1..-1])
          else
            setProperty(k, v)
          end
        }
      elsif properties.kind_of? Array
        properties.each {|p|
          if ! p.kind_of? Property
            raise "Propertie array needs to contain Property, but is '" \
              + p.class.to_s + "'."
          end
          @properties += [p]
        }
      else
        raise "Properties declarations needs to be a Hash or Array, but is '" \
          + properties.class.to_s + "'."
      end

    end
  end

end
