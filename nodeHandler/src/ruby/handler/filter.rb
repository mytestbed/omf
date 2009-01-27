#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2008 WINLAB, Rutgers University, USA
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

require 'handler/property'

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
  # - idref = reference ID
  # - properties = optional array of properties for this filter (default 'nil')
  # - returnType = optional filter's return Type (default 'long')
  #
  def Filter.create(idref, properties = nil, returnType = 'long')
    Filter.new(idref, properties, returnType)
  end

  attr_reader :idref, :properties, :returnType

  # 
  # Real filter creation
  #
  # - idref = reference ID
  # - properties = array of properties for this filter 
  # - returnType = filter's return Type 
  #
  def initialize(idref, properties, returnType)
    @idref = idref
    @properties = Array.new
    addProperties(properties)
    @returnType = returnType
  end

  #
  # Some common filter definitions
  #
  MIN_MAX = Filter.create(":min-max")
  MEAN = Filter.create("sample_mean")
  SUM = Filter.create("sample_sum")
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
    a = REXML::Element.new("filter")
  a.add_attribute("idref", idref)
  a.add_attribute("refid", idref) # for legacy reason
  a.add_attribute('returnType', returnType)

  if @properties.length > 0
      pe = a.add_element("properties")
      @properties.each {|p|
        pe.add_element(p.to_xml)
      }
    end
    return a
  end

end

