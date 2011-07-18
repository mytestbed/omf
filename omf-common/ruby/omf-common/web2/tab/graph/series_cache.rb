
require 'omf-common/oml/arel_remote'

module OMF
  module Common
    module Web2
      module Graph
        
        # This class maintains the data associated with a time series graph
        # definition. It will once, or repeatedly query the OML query service
        # to obtain and refresh data.
        #
        class SeriesCache < MObject
          attr_reader :name, :visType, :opts
          attr_reader :js_uri, :js_var_name, :js_func_name, :base_id, :base_el
          
          # Use this as the default column name for ordering streams
          DEF_STREAM_COLUMN = :oml_ts_server 
          
          # Default interval to query data source [sec]
          DEF_DATA_SOURCE_INTERVAL = 3
          
          # Default port to listen if we function as OML endpoint
          DEF_OML_ENDPOINT_PORT = 3000
          
          def initialize(name, vizType, opts, &filterProc)
            @name = name
            @visType = vizType
            @opts = opts
            @filterProc = filterProc
            @series = []
            @label2data = {}
            
            if opts[:data_source]
              start_data_loop opts
            elsif opts[:oml_endpoint] 
              start_oml_endpoint opts
            end

            @js_uri = visType ##|| DEF_VIS_TYPE # @opts[:gopts][:gtype] || 'matrix'
            @base_id = "g#{object_id.abs}"
            @base_el = "\##{@base_id}"
            @js_var_name = "oml_#{self.object_id.abs}"
            @js_func_name = 'OML.' + @js_uri.gsub("::", "_")
          end

          # def update()
          # end
          
          # Return the content of the cache. Skip any data 
          # already retirned in a previous call by the same +sessionID+.
          # If +updateFirst+ is true, check for any new data first, otherwise return 
          # current state of cache.
          #
          # TODO: Session functionality not implemented yet.
          #
          def data(sessionID, updateFirst = false, state = nil)
            @series
          end
          
          # Return javascript calling the graph build function to visualise this
          # graph. Arguments to this function include the graph data and options.
          #
          def build_js(sessionID)
            gopts = (@opts[:visOpts] || {}).dup
            gopts['session'] = sessionID
            gopts['base_el'] = base_el
            
            data = data(sessionID)
            gopts['data'] = data unless data.empty?

            func_name = js_func_name
            "var #{js_var_name} = new #{func_name}(#{gopts.to_json});"
          end
          

          private    
          
          # Start a private thread which is going to call the data source proc
          # every opts[:data_source_interval] and if that proc returns an array
          # of rows, the (optional) filter proc is called to format the result
          #      
          def start_data_loop(opts)
            interval = opts[:data_source_interval] || DEF_DATA_SOURCE_INTERVAL
            dataProc = opts[:data_source]
            Thread.new do
              begin
                while (true)
                  rows = dataProc.call(self)
                  if (rows)
                    filter_rows(rows)
                  end
                  sleep interval
                end
              rescue Exception => ex
                error ex
                debug ex.backtrace.join("\n\t") 
              end
            end
          end
          
          def filter_rows(rows)
            res = @filterProc.call(self, rows)
            res.each do |h|
              label = h[:label] || :_
              data = h[:data]
              raise "Missing :data in series '#{label}'" unless data                
              unless da = @label2data[label]
                da = @label2data[label] = {:data => []}
                da[:label] = label if h[:label]
                @series << da
              end
              da[:data].concat(h[:data])  
            end          
          end
          
          def start_oml_endpoint(opts)
            require 'socket'
            require 'omf-common/web2/tab/graph/oml_endpoint'
            
            op = opts[:oml_endpoint]
            port = op[:port] || DEF_OML_ENDPOINT_PORT
            Thread.new do
              begin
                debug "Creating OML Endpoint on port '#{port}'"
                ssocket = TCPServer.new(port)
                while (true)
                  socket = ssocket.accept
                  debug "OML stream connected"
                  ep = OMLEndpoint.new
                  ep.parse(socket) do |x|
                    x.on_row do |r|
                      filter_rows [r]
                    end
                  end
                  debug "OML stream disconnected"                  
                end
              rescue Exception => ex
                error ex
                debug ex.backtrace.join("\n\t") 
              end
            end
          end 
          
          def to_a()
            @series
          end
          
          
        end # SeriesCache
      end
    end
  end
end
