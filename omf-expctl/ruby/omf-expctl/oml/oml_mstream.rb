#
# Copyright (c) 2009 National ICT Australia (NICTA), Australia
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
# = mstream.rb
#
# == Description
#
# This class describes a measurement stream created by an OML'ified application
# or collection service
#

require "omf-expctl/oml/filter"

module OMF
  module ExperimentController
    module OML

      #
      # This class describes a measurement stream created by an OML'ified application
      # or collection service
      #
      class MStream < MObject
        @@instances = {}
        
        def self.[](uri)
          @@instances[uri] || self.find(uri)
        end

        def self.find(uri)
          @@instances[uri] || self.new(uri)
        end
      
        #def self.omlConfig(mstreams)
        #  cfg = []
        #  mstreams.each do |ms|
        #    cfg << ms.omlConfig
        #  end
        #  cfg
        #end
	#def omlConfig()
        #  puts @mdef
        #end
        
        def initialize(name, opts, application, &block)
          @mdef = name
	  @opts = opts
          @application = application
	  @filters = Array.new
          block.call(self) if block
        end
        
        #	
	# Define a Measurement Stream
	# An experimenter defines what sub-set of available measurements 
	# s/he is interested in. The default filter (pre-processing) associated
	# with these measurements are 'avg' (average) for any integer or float
	# metrics, and 'first' for any string metrics.
	# Use filter() to define Measurement Stream with more specific pre-processing
	# functions.
	#
	# example of use: 
	#  otg.measure(:mpoint => 'udp_out', :interval => 5) do |mp|
        #    mp.metric('myMetrics', 'seq_no', 'pkt_length', 'dst_host' )
        #  end
	#
	# - name = the name for this Measurement Stream (used in the resulting database)
	# - *opts = a comma-separated list of metrics to include in this Measurement Stream
	#
        def metric(name = :mandatory, *opts)
          raise OEDLMissingArgumentException.new(:metric, :name) if name == :mandatory

	  # For each of the metrics...
	  opts.each { |parameter|
            # Get its detail from the application definition
            appDef = AppDefinition[@application.to_s]
	    measurementDef = appDef.measurements[@mdef]
	    metricDef = measurementDef.metrics[parameter]
            # Set the default filter based on the metric type
	    if metricDef[:type] == "xsd:float" || metricDef[:type] == "xsd:int" \
               || metricDef[:type] == "xsd:long" || metricDef[:type] == "xsd:short"
              filterType = 'avg'
	    else
              filterType = 'first'
	    end
            # Build and Add the metric to this Measurement Stream
            filter = OMF::ExperimentController::OML::Filter.new(filterType, "#{name}_#{parameter}", {:input => parameter})  
	    @filters << filter
	  }

        end
      
	#
	# Define a Measurement Stream
	# An experimenter defines what sub-set of available measurements 
	# s/he is interested in, and what additional pre-processing (filter) should
        # be applied to the tuple stream originiating from a measurement point.
	#
	# example of use: 
	#    otg.measure(:mpoint => 'udp_out', :interval => 5) do |mp|
        #      mp.filter('myFilter1', 'avg', :input => 'pkt_length')
        #      mp.filter('myFilter2', 'first', :input => 'dst_host')
	#    end
	#
	# - name = the name for this Measurement Stream (used in the resulting database)
	# - type = the type of filter to use (e.g. avg, first, stddev)
	# - opts = a comma-separated list of key => value options for this specific filter
	#
        def filter(name = :mandatory, type = :mandatory, opts = {})
          raise OEDLMissingArgumentException.new(:filter, :name) if name == :mandatory
          raise OEDLMissingArgumentException.new(:filter, :type) if type == :mandatory

          # Build and Add the filter to this Measurement Stream
          filter = OMF::ExperimentController::OML::Filter.new(type, name, opts)  
	  @filters << filter
        end

	#
	# Return the XML representation of this Measurement Stream.
	# The OML Client should understand this XML representation
	# Examples of the outputs of this function are:
	#
        #    <mp name="udp_out" interval="1" >
	# OR
        #    <mp name="udp_out" interval="1" >
        #      <f fname="first" sname="the_sequence" pname="seq_no"/>
        #    </mp>
	#
	# [Return] an XML representation for this Measurement Stream
	#
	def to_xml()
	  el = REXML::Element.new('mp')
	  el.add_attribute("name", "#{@mdef}")
	  if @opts.key?(:interval)
	    el.add_attribute("interval", "#{@opts[:interval]}")
          elsif @opts.key?(:samples)
	    el.add_attribute("samples", "#{@opts[:samples]}")
          end
	  if @filters.size > 0
            @filters.each { |f|
              el.add_element(f.to_xml)
	    }
	  end
	  return el
	end
        
        def SERVER_TIMESTAMP()
          'oml_ts_server'  # should be more descriptive
        end

      end # MStream
    
    end # module OML
  end # module ExperimentController
end # OMF
