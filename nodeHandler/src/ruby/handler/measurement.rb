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
# = measurement.rb
#
# == Description
#
# This file defines the 'Measurement' and 'MutableMeasurement' classes
#
require "handler/property.rb"
require "handler/metric.rb"
require "handler/filter.rb"

#
# This class represents a measurement point used in an application definition
#
class Measurement

  include CreatePropertiesModule

  # ID for this measurement point
  attr_reader :id

  # Description of the measurement point
  attr_reader :description

  # List of global properties for filtering
  attr_reader :properties

  attr_reader :metrics

  attr_reader :filterMode

  # 
  # Create a new measurement point
  #
  # - mDef = definition for this new measurement point
  # - filterMode = Type of OML filter - time or sample
  # - properties = array of properties for this new measurement point
  # - metrics = metrics to use for this new measurement point
  #
  def initialize(mDef, filterMode = nil, properties = nil, metrics = nil)
    @mDef = mDef
    @id = mDef.id
    @filterMode = filterMode

    @properties = Array.new
    addProperties(properties)

    @metrics = Hash.new
    if metrics != nil
      metrics.each {|e|
        if e.kind_of? Array
          name = e.shift
          addMetric(name, e)
        else
          raise "Metric definition '" + e + "' needs to be an array"
        end
      }
    end
  end


  #
  # Add a metric to this measurement point
  #
  # - refid = reference ID for this new metric
  # - filter = filter to use for this new metric
  #
  def addMetric(refid, filter = nil)
    metricDef = @mDef.metrics[refid]
    if metricDef == nil
      raise "Unknown metric '#{refid}' for measurement point '#{@mDef.id}'"
    end
    m = Metric.new(refid, metricDef)
    if filter != nil
      if filter.kind_of? Filter
        m.addFilter(filter)
      elsif filter.kind_of? Array
        filter.each {|f|
          m.addFilter(f)
        }
      else
        raise "Filter needs to be of type Filter or an array, but is '" + filter + "'."
      end
    end
    metrics[refid] = m
    return m
  end

  private :addMetric

  #
  # Return the Measurement point definition as an XML element
  #
  # [Return] an XML element defining this measurement point
  #
  def to_xml
    a = REXML::Element.new("measurement")
  a.add_attribute("name", id)

  if @properties.length > 0
      pe = a.add_element("properties")
      @properties.each {|p|
        pe.add_element(p.to_xml)
      }
    end

    metrics.each_value {|m|
      a.add_element(m.to_xml)
    }
    return a
  end

end

#
# This class represents a mutable measurement point used in an application definition
#
class MutableMeasurement < Measurement

  #
  # Alternative syntax to 'addMetric'
  #
  def add(refid, filter = nil)
    addMetric(refid, filter)
  end

  #
  # Change the filter to use for this measurement poin
  #
  # - filterMode = new OML filter mode (time or sample)
  # - options = optional properties for this filter
  #
  def filter(filterMode, options)
    @filterMode = filterMode
    addProperties(options)
  end

  #
  # Use a time filer with a specific sample rate for this measurement point
  # 
  # - time = sample rate in sec
  #
  def useTimeFilter(time)
    filter(Filter::TIME, {Filter::SAMPLE_SIZE => time})
  end

  #
  # Use a sample filer with a specific size for this measurement point
  #
  # - size = sample size to use
  #
  def useSampleFilter(size)
    filter(Filter::SAMPLE, {Filter::SAMPLE_SIZE => size})
  end

end
