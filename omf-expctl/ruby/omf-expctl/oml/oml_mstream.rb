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
        
        def initialize(opts, application, &block)
          @mdef = opts[:mpoint]
	  @opts = opts
          @application = application
	  @filters = Array.new
          block.call(self) if block
        end
        
        #def metric(name = :mandatory, metrics = {h1, h2, h3})
        def metric(name = :mandatory, *opts)
          raise OEDLMissingArgumentException.new(:metric, :name) if name == :mandatory

	  info "TDEBUG - metric - appliction: #{@application} - called: #{opts.to_s}"

	  opts.each { |parameter|
	  
            info "TDEBUG - metric - parameter: #{parameter}"

            appDef = AppDefinition[@application.to_s]
	    measurementDef = appDef.measurements[@mdef]
	    metricDef = measurementDef.metrics[parameter]
	    if metricDef[:type] == "xsd:float" || metricDef[:type] == "xsd:int" || metricDef[:type] == "xsd:long" || metricDef[:type] == "xsd:short"
              filterType = 'avg'
	    else
              filterType = 'first'
	    end
            filter = OMF::ExperimentController::OML::Filter.new(filterType, "#{name}_#{parameter}", {:input => parameter})  
	    info "TDEBUG - metric - filter - #{filterType} - #{name} - #{parameter}"
	    @filters << filter
	  }

        end
      
        #def filter(name = :mandatory, type = :mandatory, otps = {h1, h2, h3})
        def filter(name = :mandatory, opts = {})
          raise OEDLMissingArgumentException.new(:filter, :name) if name == :mandatory
        end

        
        #def omlConfig()
        #  puts @mdef
        #end

	#
	# An example of an XML representation of a MStream
	#
        #    <mp name="udp_out" interval="1" >
	# OR
        #    <mp name="udp_out" interval="1" >
        #      <f fname="first" sname="the_sequence" pname="seq_no"/>
        #    </mp>
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
