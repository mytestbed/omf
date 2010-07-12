require 'json'

module OMF
  module Common
    module Web
      module Graph3
        @@graphs = []
        
        def self.configure(server, options = {})
          opts = options.dup
          opts[:graphs] = @@graphs
          server.mount('/graph3/show', GraphServlet, opts)
          server.mount('/graph3/update', UpdateServlet, opts)
          
#          if NodeHandler.debug?
#            debug_init()
#          end
          
          server.addTab :graph3, "/graph3/show", :name => "PV Graphs", :title => "All defined graphs"
          
          if NodeHandler.debug?
            debug_graphs(opts)
          end  
        end
        
        def self.debug_graphs(opts)
          dim = 6
          dh = dim / 2 - 0.5
          data = []
          dim.times do |y|
            data << (row = [])
            dim.times do |x|
              # cluster nodes
              v = 5 * rand
              if !((x > dh && y > dh) || (x < dh && y < dh))
                v += 15
              end
              row << v
            end
          end
          
          self.addNetworkGraph 'force', :gtype => 'force' do |n|
            opts = {}
            data.each_index do |y|
              row = data[y]
              from = "node#{y}"
              row.each_index do |x|
                to = "node#{x}"
                v = row[x]
                opts[:spring_force] = v > 5 ? 0.01 : 0.5
                n.addLink from, to, v, opts unless (from == to)
              end
            end
          end

          self.addNetworkGraph 'matrix', :gtype => 'matrix' do |n|
            data.each_index do |y|
              row = data[y]
              from = "node#{y}"
              row.each_index do |x|
                to = "node#{x}"
                n.addLink from, to, row[x], opts unless (from == to)
              end
            end
          end

        end

        def self.addGraph(name, opts = {}, &dataProc)
          g = {}
          g[:name] = name
          g[:gopts] = opts
          g[:dataProc] = dataProc
          @@graphs << g
        end

        def self.addNetworkGraph(name, opts = {}, &netProc)
          g = {}
          g[:name] = name
          g[:gopts] = opts.dup
          g[:netProc] = netProc
          @@graphs << g
        end

        class NetworkBuilder
          def addNode(name, param = {})
            unless id = @node_name2id[name]
              id = @node_name2id[name] = @node_name2id.length
              np = param.dup
              np[:nodeName] = name
              @nodes << np
            end
            id
          end
          
          def addLink(from, to, value, param = {})
            from_id = addNode(from)
            to_id = addNode(to)
            lp = param.dup
            lp[:source] = from_id
            lp[:target] = to_id
            lp[:value] = value
            @links << lp
          end
        
          def self.build(buildProc, opts = {})
            gb = self.new
            buildProc.call(gb)
            varName = opts[:var_name] || 'oml_data'
            data = gb.to_js(varName)
          end
          
          def initialize()
            @nodes = []
            @node_name2id = {}
            @links = []
          end
          
          def to_js(varName = 'oml_data')
            h = {:nodes => @nodes, :links => @links}
            "var #{varName} = #{h.to_json};"
          end
        end # NetworkBuilder

        class GraphDescription
          @@sessions = {}

          attr_reader :lines, :sessionID
          
          def addLine(data, lopts = {})
            l = lopts.dup
            l[:type] = :line
            l[:data] = data
            @lines << l
          end      
          
          def addData(data, opts = {})
            n = opts.dup
            n[:data] = "var oml_data = #{data}"
            @graphs << n
          end
          
          def addNetwork(nodes, links, nopts = {})
            n = nopts.dup
      	    na = Array.new(nodes.size)
            nodes.each do |name, index| na[index] = {:nodeName => name} end
            h = {:nodes => na, :links => links}
            n[:data] = "var oml_data = #{h.to_json}"
            @graphs << n
          end

          def data()
	          (@graphs[0] || {})[:data]
	        end

          def session()
            unless session = @@sessions[@sessionID]
              session = @@sessions[@sessionID] = {}
            end
            session
          end    
          
          def opts()
            @opts[:gopts]
          end
          
          def protovis()
            js_uri = @opts[:gopts][:gtype] || 'matrix'
            
            js = nil
            if (loadProc = @opts[:fileLoadFunc])
              begin 
                js = loadProc.call(js_uri, '.js')
              rescue IOError => ioerr
              end
            end
            if js.nil?
              fname = File.join(File.dirname(__FILE__), "#{js_uri}.js")
              js = File.read(fname) if File.exists?(fname)
            end
            if js.nil?
              raise "Unknown graph definition '#{type}"
            end
            js
          end
          
          def initialize(sessionID, opts)
            @sessionID = sessionID
            @opts = opts
            @graphs = []
            if (dataProc = opts[:dataProc])
              dataProc.call(self)
#              g[:ldata] = graph.lines.to_json 
            end
            if (nwProc = opts[:netProc])
              gopts = opts[:gopts].dup
              gopts[:data] = NetworkBuilder.build(nwProc, gopts)
              @graphs << gopts
            end

          end
        end
        
        class GraphServlet  < WEBrick::HTTPServlet::AbstractServlet
          
          def do_GET(req, res)
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = :graph3

            sessionID = opts[:session_id] = "sess#{(rand * 10000000).to_i}"
            gid = (req.query['id'] || 0).to_i
            opts[:show_graph_id] = gid
  
            if gx = opts[:graphs][gid]
              if (loadProc = opts[:fileLoadFunc])
                gx[:fileLoadFunc] = loadProc
              end
              opts[:gd] = GraphDescription.new(sessionID, gx)
            else
              opts[:gd] = nil
              if opts[:graphs].length > 0
                opts[:flash][:alert] = "Unknown graph id '#{gid}'"
              else
                opts[:flash][:alert] = "No graphs defined"
              end
            
            end
            res.body = MabRenderer.render('graph3/show', opts)
          end
        end

      
        class UpdateServlet  < WEBrick::HTTPServlet::AbstractServlet
  
          def do_GET(req, res)
            res['Content-Type'] = "text/json"
            opts = @options[0]
            gid = (req.query['id'] || 0).to_i
            
            res['Content-Type'] = "application/ecmascript"
            if gx = opts[:graphs][gid]
              sessionID = req.query['sid'] || 'unknown'
              gd = GraphDescription.new(sessionID, gx)
              res.body = gd.data
	    else
              res.body = %{
var oml_data = {"nodes":[{"nodeName":"192.168.1.2"},{"nodeName":"192.168.1.3"},{"nodeName":"192.168.1.4"},{"nodeName":"192.168.1.5"},{"nodeName":"192.168.1.6"}],"links":[{"target":1,"value":1.05086363636364,"source":0
},{"target":2,"value":1.16,"source":0},{"target":3,"value":0.873318181818182,"source":0},{"target":4,"value":1.29881818181818,"source":0},{"target":0,"value":0.992772727272727,"source":1},{"target":2,"value":0.8801363
63636364,"source":1},{"target":3,"value":0.886136363636364,"source":1},{"target":4,"value":1.09186363636364,"source":1},{"target":0,"value":0.9494375,"source":2},{"target":1,"value":0.914625,"source":2},{"target":3,"v
alue":80.9961,"source":2},{"target":4,"value":0.9046875,"source":2},{"target":0,"value":0.934727272727273,"source":3},{"target":1,"value":0.896727272727273,"source":3},{"target":2,"value":83.5786666666666,"source":3},
{"target":4,"value":82.1885,"source":3},{"target":0,"value":0.908428571428571,"source":4},{"target":1,"value":0.891785714285714,"source":4},{"target":2,"value":0.9015,"source":4},{"target":3,"value":80.8373333333333,"
source":4}]};
              }
#              res.body('');
            end
          end
        end
        
      end
    end
  end
end
