#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
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
# = filter.rb
#
# == Description
#
# This file contains the definition of the class Filter
#

require 'omf-expctl/property'

module OMF
  module ExperimentController
    module OML

#
# This class describes a measurement filter
#
class Filter

  FILTER_URI = "uri:oml:filter"
  SAMPLE = "sample_based"
  TIME = "time_based"
  SAMPLE_SIZE = "trigger" # number of samples
  SAMPLE_RATE = "trigger" # dwell time in seconds
  #SAMPLE_SIZE = FILTER_URI + ":trigger" # number of samples - Debug
  #SAMPLE_RATE = FILTER_URI + ":trigger" # dwell time in seconds - Debug

  # Filter definition are below as the need to be after the initialize function
  include CreatePropertiesModule

  # 
  # Create a new filter
  #
  # - idref = reference ID, this is the Type of this filter
  # - name = a unique name for this filter
  # - properties = optional array of properties for this filter (default 'nil')
  #
  def Filter.create(idref, name, properties = nil)
    Filter.new(idref, name, properties)
  end

  attr_reader :idref, :properties, :returnType

  # 
  # Real filter creation
  #
  # - idref = reference ID, this is the Type of this filter
  # - name = a unique name for this filter
  # - properties = optional array of properties for this filter (default 'nil')
  #
  def initialize(idref, name, properties = nil)
    @idref = idref
    @name = name
    @properties = Array.new
    addProperties(properties)
  end

  #
  # Some common filter definitions
  #
  #MIN_MAX = Filter.create(":min-max")
  #MEAN = Filter.create("sample_mean")
  #SUM = Filter.create("sample_sum")
  #MIN_MAX = Filter.create(FILTER_URI + ":min-max")
  #MEAN = Filter.create(FILTER_URI + ":mean")

  #
  # Clone/Copy this filter
  #
  # - properties = optional array of properties for the resulting clone/copy
  #
  # [Return] the clone filter
  #
  def clone(properties = nil)
    f = Filter.new(idref, @properties)
    f.addProperties(properties)
    return f
  end

  #
  # Return the object definition of this Filter as an XML element
  #
  # [Return] the XML element representing this filter
  #
  def to_xml
    el = REXML::Element.new("f")

    # In the current Filter handling by OML Server/Client
    # pname is the input for the filter, and it is an attribute
    # of the filter element in XML
    # However, in the future there could be many inputs 
    # to a filter, thus input will become a child element of the
    # filter XML element.
    if @properties.length > 0
      @properties.each {|p|
        el.add_attribute("pname", p.value) if p.idref == :input
      }
    end
    el.add_attribute("fname", @idref)
    el.add_attribute("sname", @name)

    # Support for future evolution of Filter
    #a.add_attribute("idref", idref) 
    #if @properties.length > 0
    #  pe = a.add_element("properties")
    #  @properties.each {|p|
    #    pe.add_element(p.to_xml)
    #  }
    #end
    return el
  end

end

    end # module OML
  end # module ExperimentController
end # OMF 
