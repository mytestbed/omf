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
# = appProperty.rb
#
# == Description
#
# This class describes an application property
#

class AppProperty
  
  DEF_TYPE = :string
  DEF_LAST_ORDER = 999

  #
  # Unmarshall an AppProperty instance from an XML tree.
  #
  # - appDefRoot = Root of the XML tree containing the property definition
  #
  # [Return] a new AppProperty object holding the unmarshalled result
  #
  def AppProperty.from_xml(defRoot)
    if (defRoot.name != "property")
      raise "Property definition needs to start with an 'property' element"
    end
    name = defRoot.attributes['id']
    description = mnemonic = type = constraints = nil
    isDynamic = false
    defRoot.elements.each { |el|
      case el.name
      when 'name' : name = el.text
      when 'description' : description = el.text
      when 'mnemonic' : mnemonic = el.text
      when 'type' : type = el.text
      when 'constraints' : constraints = el.text
      when 'dynamic' : isDynamic = el.text == 'true'
      else
  warn "Ignoring element '#{el.name}'"
      end
    }
    p = AppProperty.new(name, description, mnemonic, type, isDynamic, constraints)
    return p
  end

  # Name of this property 
  attr_reader :name

  # Description of this property
  attr_reader :description 

  # Mnemonic (if any) used for this property
  attr_reader :mnemonic

  #
  # Create a new Property (AppProperty)
  #
  # - name = name for this property
  # - descritpion = some text describing this property
  # - mmemonic = mnemonic to use for this property
  # - options = optional list of options associated with this property
  #
  def initialize(name, description, mnemonic, options = {})
    @name = name
    @description = description
    @mnemonic = mnemonic
    @options = options
    if !@options.has_key?(:order)
      @options[:order] = DEF_LAST_ORDER
    end
  end

  #
  # Return true if this AppProperty has its ':dynamic' option set. If true, 
  # this property can be changed dynamically during the execution of the
  # application
  #
  # [Return] true/false
  #
  def dynamic?
    @options[:dynamic] == true
  end

  #
  # Return the type of this property described by this AppProperty.
  # The type of this property is the one set as a value to the ':type' option.
  #
  # [Return] the type of this property, 'nil' if no value was assigned to the ':type' option
  #
  def type
    return @options[:type] || DEF_TYPE
  end

  #
  # Return the String used for a command line argument (i.e. the argument name that 
  # appears before a value). If a mnemonic has been set for this AppProperty, then
  # return it, if not return the full argument name (e.g. "-v" versus "--version")
  #
  # [Return] a String
  #
  def commandLineFlag
    if (m = mnemonic) != nil
      return "-#{m}"
    elsif (@options != nil)
      if @options[:use_name] == false
         return ""
      end
    end
    return "--#{name}"
  end

  #
  # Return the value of the ':order' option for this AppProperty
  #
  # [Return] 
  #
  def order()
    @options[:order] || DEF_LAST_ORDER
  end

  def <=>(other)
    order <=> other.order
  end

  #
  # Return the definition of this instance of AppProperty as an XML element
  # (does the reverse of 'from_xml') 
  #
  # [Return] an XML element
  #
  def to_xml
    a = REXML::Element.new("property")
  a.add_attribute("id", name)
    a.add_element("name").text = name
    if (description)
      a.add_element("description").text = description
    end
    if (m = mnemonic)
      if m.kind_of?(Integer)
        m = m.chr
      end
      a.add_element("mnemonic").text = m
    end
    if (@options)
      p @options
      @options.each {|name, value|
        a.add_element(name.to_s).text = value.to_s
      }
    end
    return a
  end


end
