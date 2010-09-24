require 'json'
require 'omf-common/web/tab/graph3/series_builder'
require 'omf-common/web/tab/graph3/network_builder'

module OMF
  module Common
    module Web
      module Graph3

        class GraphDescription < MObject
          @@sessions = {}
          
          DEF_VIS_TYPE = 'line_chart'

          attr_reader :sessionID
          
#          def addLine(data, lopts = {})
#            l = lopts.dup
#            l[:type] = :line
#            l[:data] = data
#            @lines << l
#          end      
          
#          def addData(data, opts = {})
#            n = opts.dup
#            n[:data] = "var oml_data = #{data.to_json}"
#            @graphs << n
#          end
          
#          def addNetwork(nodes, links, nopts = {})
#            if @graph
#              error "Can only have one graph declaration per graph"
#              return
#            end
#            
#            @graph = nopts.dup
#      	    na = Array.new(nodes.size)
#            nodes.each do |name, index| na[index] = {:nodeName => name} end
#            @graph[:data] = {:nodes => na, :links => links}
#          end

          # Return javascript calling the graph build function to visualise this
          # graph. Arguments to this function include the graph data and options.
          #
          def build_js(func_name = nil)
            d = data()
            gopts = (opts() || {}).dup
            gopts['session'] = @sessionID
            unless func_name
              func_name = func_name()
            end
            "#{func_name}(#{d.to_json}, #{gopts.to_json}, false);"
	        end
          
          def func_name()
            "oml_" + @js_uri.gsub("::", "_")
          end
          
          def data()
            return @data if @data
            
            if (seriesProc = @opts[:dataProc])
              @data = SeriesBuilder.build(seriesProc, self)
            elsif (nwProc = @opts[:netProc])
              @data = NetworkBuilder.build(nwProc, self)
            else
              error "No declarations on how to obtain graph data"
              return ""
            end
          end
          
          
          # Return the javascript code as string defining the
          # visualisation of the graph's data
          #
          def describe_js()
            js = nil
            if (loadProc = @opts[:fileLoadFunc])
              begin 
                js = loadProc.call(@js_uri, '.js')
              rescue IOError => ioerr
              end
            end
            if js.nil?
              fname = File.join(File.dirname(__FILE__), "pv/#{@js_uri}.js")
              js = File.read(fname) if File.exists?(fname)
            end
            if js.nil?
              raise "Unknown graph definition '#{@js_uri}"
            end
            js
          end
          

          def session()
            unless @session
              @session = @@sessions[@sessionID] ||= {}
              @session[:ts] = Time.now
            end
            @session
          end    
          
          def opts()
            @opts[:gopts]
          end
          
          
          def initialize(sessionID, opts)
            @sessionID = sessionID
            @opts = opts
            @js_uri = @opts[:visType] || DEF_VIS_TYPE # @opts[:gopts][:gtype] || 'matrix'

#            @graph = nil
#            @lines = []
            @data = nil
          end
          
          private
          
          
        end
        
      end
    end
  end
end
