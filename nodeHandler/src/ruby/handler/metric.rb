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
# = metric.rb
#
# == Description
#
# This file defines the 'Metric' classe
#

#
# This class defines a metric for a measurement point
# A metric can include a list of filters
#
class Metric

  # Mapping between OML data types and SQL types.
  # Fix the duplication of xsd: and plain types.
  XSD2SQL = {
    "xsd:float" => "FLOAT NOT NULL",
    "xsd:int" => "INTEGER NOT NULL",
    "xsd:long" => "INTEGER NOT NULL",
    "xsd:short" => "INTEGER NOT NULL",
    "xsd:bool" => "DO NOT KNOW",
    "xsd:string" => "CHAR(32) NOT NULL",
    "float" => "FLOAT NOT NULL",
    "int" => "INTEGER NOT NULL",
    "long" => "INTEGER NOT NULL",
    "short" => "INTEGER NOT NULL",
    "bool" => "DO NOT KNOW",
    "string" => "CHAR(32) NOT NULL"
  }

  attr_reader :refid

  # Filters added to metric
  attr_reader :filters, :type, :seqNo

  #
  # Create a new Metric object
  #
  # - refid = reference ID for this metric
  # - metricDef = a Hash defining this metric (keys are 'type' and 'seqNo')
  #
  def initialize(refid, metricDef)
    @refid = refid
    @type = metricDef['type']
    @seqNo = metricDef['seqNo']
  end

  #
  # Add a Filter to this Metric instance
  #
  # - filter =  the Filter object to add
  # - properties = optional properties for the added Filter (default=nil)
  #
  def addFilter(filter, properties = nil)
    if !(filter.kind_of? Filter)
      raise "Needs to be a filter, but is a #{filter.class} (#{filter.inspect})"
    end
    if (properties != nil)
      filter = filter.clone(properties)
    end
    if @filters == nil
      @filters = Array.new
    end
    @filters += [filter]
  end

  #
  # Return the definition of this Metric object as an XML element
  #
  # [Return] an XML element defining this Metrick object
  #
  def to_xml
    a = REXML::Element.new("metric")
  a.add_attribute("name", refid)
    a.add_attribute("id", refid) # for legacy reasons
    a.add_attribute("refid", refid) # for legacy reasons

    # for legacy reasons
    t = type
    if (t =~ /xsd:/) == 0
      t = t[4..-1]
    end
  a.add_attribute("type", t)
  #a.add_attribute("seqNo", @seqNo)

  if filters != nil
    filters.each {|f|
      a.add_element(f.to_xml)
    }
    end
    return a
  end

  #
  # Return a string describing the columns needed in an OML database to capture
  # the metric described by this object. Note, that a separate column is needed
  # for every filter.
  #
  # [Return] An SQL column definition as a String
  #
  def to_sql
  if filters == nil
    return "#{refid} #{XSD2SQL[type]}"
  else
    sql = ""
    spacer = ""
    filters.each {|f|
      sql += "#{spacer}#{refid}_#{f.idref} #{XSD2SQL[f.returnType]}"
      spacer = ", "
    }
    return sql
    end
  end

end
