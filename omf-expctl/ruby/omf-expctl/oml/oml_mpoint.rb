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
# = appMeasurement.rb
#
# == Description
#
# This class describes a measurement point used in an application definition
#

module OMF
  module ExperimentController
    module OML

      class MPoint
      
      
        FLOAT = Float
      
        @@conversion = {
          Float => "xsd:float",
          Integer => "xsd:int",
          String => "xsd:string",
          'float' => "xsd:float",
          'int' => "xsd:int",
          'string' => "xsd:string",
          'long' => "xsd:long",
          'short' => "xsd:short",
          'boolean' => "xsd:bool",
          'bool' => "xsd:bool",
          'flag' => "xsd:bool"          
        }
      
      
        #
        # Unmarshall an instance from an XML tree.
        #
        # - appDefRoot = Root of the XML tree containing the measurment definition
        #
        # [Return] a new AppMeasurement object holding the unmarshalled result
        #
        def self.from_xml(defRoot)
          if (defRoot.name != "measurement")
            raise "Measurement definition needs to start with an 'measurement' element"
          end
          id = defRoot.attributes['id']
          metrics = Array.new
          description = nil
          defRoot.elements.each { |el|
            case el.name
            when 'description' : description = el.text
            when 'metric'
              name = type = description = nil
              el.attributes.each { |n, v|
                case n
                when 'id' : name = v
                when 'type' : type = v
                else
                  warn "Ignoring metric attribute '#{n}'"
                end
              }
              description = el.elements['description']
              metrics << [name, type, description]
            else
              warn "Ignoring measurement element '#{el.name}'"
            end
          }
          m = self.new(id, description, metrics)
          return m
        end
      
        # ID for this measurement point
        attr_reader :id
      
        # Description of the measurement point
        attr_reader :description
      
        # Hash holding the metrics associated with this measurement point
        attr_reader :metrics
      
        #
        # Create a new measurement point (AppMeasurement) instance
        #
        # - id =  the ID for this measurement point
        # - description =  some text describing this measurement point
        # - metrics = an array or hash containing the metrics to use for this measurement point
        #
        def initialize(id, description, metrics = nil)
          @id = id
          @description = description
          @metrics = Hash.new
          if metrics != nil
            metrics.each {|e|
              if e.kind_of? Array
                addMetric(e[0], e[1], e.length == 3 ? e[2] : nil)
              elsif e.kind_of? Hash
                addMetric(e["name"], e["type"], e["description"])
              else
                raise "Metric definition '" + e + "' needs to be either and array or a hash"
              end
            }
          end
        end
      
        #
        # Add a metric to this measurement point
        #
        # - name = name for this metric
        # - type = type for this metric
        # - description = some text describing this metric
        #
        def defMetric(name = nil, type = nil, description = nil)
          raise OEDLMissingArgumentException.new(:defMetric, :name) unless name
          raise OEDLMissingArgumentException.new(:defMetric, :type) unless type
          
          puts "TDEBUG - defMetric - #{name} - #{type} - #{description}" 

          if @metrics[name] != nil
            raise "Metric '" + name + "' already defined."
          end
          type = type.to_s
          if (type =~ /xsd:/) != 0
            if (! @@conversion.key?(type))
              raise "Unknown type '#{type}' for metric '#{name}'."
            end
            type = @@conversion[type]
          end
          @metrics[name] = {"type" => type, "description" => description, 'seqNo' => @metrics.length}
        end
      
        #
        # _Deprecated_ - Use defMetric(...) instead
        #
        def addMetric(name, type, description = nil)
          warn("'addMetric' is depreciated! Use 'defMetric' instead")
          defMetric(name, type, description)
        end
      
        #
        # Return the definition of this instance of measurement point as an XML element
        # (does the reverse of 'from_xml') 
        #
        # [Return] an XML element
        #
        def to_xml
          a = REXML::Element.new("measurement")
          a.add_attribute("id", id)
          a.add_element("description").text = description
          metrics.each {|id, v|
            m = REXML::Element.new("metric")
            m.add_attribute("id", id)
            m.add_attribute("type", v["type"])
            description = v["description"]
            if description != nil
              m.add_element("description").text = description
            end
            a.add_element(m)
          }
          return a
        end
      
      end # MPoint
    end # module OML
  end # module ExperimentController
end # OMF      
      
