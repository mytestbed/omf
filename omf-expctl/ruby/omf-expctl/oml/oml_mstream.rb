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
          @@instances[uri] #|| self.find(uri)
        end

        def self.find(uri)
          @@instances[uri] #|| self.new(uri)
        end
        
        def self.select(&block)
          @@instances.select(&block)
        end

        def self.each(&block)
          @@instances.each(&block)
        end
        
        def self.collect(&block)
          @@instances.collect(&block)
        end
        
        Xsd2SqlType = {
          'xsd:string' => 'TEXT',
          'xsd:long' => 'INTEGER',
          'xsd:float' => 'REAL'
        }
        
        attr_reader :name, :tableName, :filters
        
        def initialize(name, appRef, opts, application, &block)
          @mdef = @name = name

          # ALERT: this is a bit of a hack
          appDef = AppDefinition[application.to_s]
          tblPrefix = appDef.omlPrefix || appDef.path.split('/')[-1]
          @tableName = "#{tblPrefix}_#{name}"
          puts ">>> TABLE_NAME: #{@tableName}"
          #@tableName = "#{appRef.split(':')[-1]}_#{name}"

          @appRef = appRef
          @opts = opts || {}
          @single_sample_mode = (@opts[:samples] == 1)

          #puts ">>>>> MSTREAM #{name} - #@single_sample_mode #{opts.inspect}"
          @application = application
          @filters = Array.new

          @@instances[name] = @@instances["#{appRef}:#{name}"] = @@instances[@tableName] = self

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
      	  opts.each do |parameter|
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
      	  end
        end
      
      	#
      	# Define a Measurement Stream
      	# An experimenter defines what sub-set of available measurements 
      	# s/he is interested in, and what additional pre-processing (filter) should
        # be applied to the tuple stream originiating from a measurement point.
      	#
      	# example of use: 
      	#    otg.measure(:mpoint => 'udp_out', :interval => 5) do |mp|
        #      mp.filter('pkt_length', 'avg')
        #      mp.filter('dst_host', 'first')
      	#    end
      	#
      	# - pname = the parameter name of the MP to attach filter to
      	# - type = the type of filter to use (e.g. avg, first, stddev)
      	# - opts = a comma-separated list of key => value options for this specific filter
        #
        # NOTE: This command should really ONLY have opts as we also support multi parameter filters
        #
        #    mp.filter(:pname => 'pkt_length', :filter => 'avg', :alias => '' ...)
      	#
        def filter(pname = :mandatory, type = :mandatory, fopts = {})
          raise OEDLMissingArgumentException.new(:filter, :pname) if pname == :mandatory
          raise OEDLMissingArgumentException.new(:filter, :type) if type == :mandatory
          
          unless (fspec = FilterSpec[type])
            raise OEDLIllegalArgumentException(:filter, :fname)
          end

          # Build and Add the filter to this Measurement Stream
          #fopts = {}
          fopts[:pname] = pname
          fopts[:fname] = type
          fopts[:ms] = self
          fopts[:fspec] = fspec
          filter = OMF::ExperimentController::OML::Filter.new(fopts)  
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
      	
      	def arelTable()
          require "omf-expctl/oml/oml_arel"

          Table.new(self) 
      	end
      	
      	# Return an array containing the names of the columns of the 
      	# respective table in the OML database
      	#
      	def columns()
      	  cols = {}
          cols['oml_sender_id'] = {:type => 'INTEGER'}
          cols['oml_seq'] = {:type => 'INTEGER'}
          cols['oml_ts_client'] = {:type => 'REAL'}
          cols['oml_ts_server'] = {:type => 'REAL'}
      	  if @filters.size > 0
      	    @filters.each do |f|
              cols.merge!(f.columns)      	      
      	    end
      	  else
            appDef = AppDefinition[@application.to_s]
            appDef.measurements[@mdef].metrics.each do |name, opts|
              #[name] = {:type => type, :description => description, :seqNo => @metrics.length}
              case (type = opts[:type])
              when 'xsd:string' then 
                cols[name] = {:type => 'TEXT'}
              when 'xsd:long', 'xsd:float' then
                if @single_sample_mode
                  cols[name] = {:type => Xsd2SqlType[type]}
                else
                  cols["#{name}_avg"] = cols["#{name}_min"] = cols["#{name}_max"] = {:type => 'REAL'}
                end
              else
                error "Type '#{opts[:type]}' for '#{name}' not implemented"
              end
      	    end
      	  end
          cols      	  
      	end
        
        def SERVER_TIMESTAMP()
          'oml_ts_server'  # should be more descriptive
        end

      end # MStream
      
    
    end # module OML
  end # module ExperimentController
end # OMF
