module OMF
  module Common
    module Web2
      module Graph
        class NetworkBuilder
          attr_reader :session, :opts
          
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
          
          
          def self.build(buildProc)
            b = self.new(session, opts)
            buildProc.call(b)
          end
          
          def initialize(session, opts)
            @session = session
            @opts = opts

            @nodes = []
            @node_name2id = {}
            @links = []
          end
          
          def to_js()
            h = {:nodes => @nodes, :links => @links}
            h.to_json
          end
        end # NetworkBuilder
      end
    end
  end
end
