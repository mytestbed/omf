require 'webrick'
require 'webrick/httputils'


module OMF
  module ExperimentController
    module Web
      module GMap
        VIEW = :gmap
        def self.configure(server, options = {})
          server.mount('/gmap/show', GMapServlet, options)
          server.mount('/gmap/update', GMapUpdateServlet, options)
          
          server.addTab(VIEW, "/gmap/show", :name => 'Map',
              :title => "Map of experiment area")
        end
        
        class MapContext
          @@sessions = {}
          
          def addPath(name = nil, &block)
            unless name
              name = "p#{@paths.length}"
            end
            p = @paths[name] = PathContext.new
            if block
              block.call(p)
            end
          end
          
          def initialize()
            @paths = {}
          end

#          attr_reader :lines, :sessionID
          
#          def addLine(data, lopts = {})
#            l = lopts.dup
#            l[:data] = data
#            @lines << l
#          end      
#          
#          def session()
#            unless session = @@sessions[@sessionID]
#              session = @@sessions[@sessionID] = {}
#            end
#            session
#          end    
#          
#          def opts()
#            @opts[:gopts]
#          end
#          
#          def initialize(sessionID, opts)
#            @sessionID = sessionID
#            @opts = opts
#            @lines = []
#            if (dataProc = opts[:dataProc])
#              dataProc.call(self)
##              g[:ldata] = graph.lines.to_json 
#            end
#          end
        end # MapContext 
        
        class PathContext

          attr_accessor :color, :width  # can that be dynamically changed?
          
          # register the update function which is called 
          # every +interval+
          #
          def update(interval = 3.0, &updateProc)
            @updateInterval = interval
            @updateProc = updateProc
          end 

          # Support path specific session state
          def [](k)
            @session[k]
          end

          def []=(k, v)
            @session[k] = v
          end
          
          def initialize()
            @session = {}            
          end
        end # PathContext 
          

 

        class GMapServlet  < WEBrick::HTTPServlet::AbstractServlet
          
   
          def do_GET(req, res)
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = VIEW
  
            opts[:session_id] = "sess#{(rand * 10000000).to_i}"
            opts[:javascript_includes] = "http://maps.google.com/maps?file=api&amp;v=2&amp;key=ABQIAAAAzr2EBOXUKnm_jVnk0OJI7xSosDVG8KKPE1-m51RBrvYughuyMxQ-i1QfUnH94QxWIa6N4U6MouMmBA"
            opts[:body_attr] = {:onload => "initialize()", :onunload => "GUnload()"}
            res.body = MabRenderer.render('gmap/show', opts, ViewHelper)
          end
        end
        
        class GMapUpdateServlet  < WEBrick::HTTPServlet::AbstractServlet
          @@sessions = {}
          
          def do_GET(req, res)
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = :gmap
            
            res['Content-Type'] = "text/json"
            opts = @options[0]
            gid = (req.query['id'] || 0).to_i
            
            res['Content-Type'] = "application/ecmascript"
            if gx = opts[:graphs][gid]
              sessionID = req.query['sid'] || 'unknown'
              gd = GraphDescription.new(sessionID, gx)
              res.body = "plot(#{gd.lines.to_json});"
            else
              res.body('');
            end
            
            
            body = []
            session_id = req.query['sid'] || 'unknown'
            #MObject.debug(:web, "update for #{session_id}")
            unless session = @@sessions[session_id]
              session = @@sessions[session_id] = {:index => 0}
              body << "createPolyline('foo', '#0000ff', 8);"
            end
            index = session[:index]
            
            #res.body = "{'method': 'foo'}"
            lat, lng = session[:last] || [37.4419, -122.1419]
            lat += 0.01 * (rand - 0.5)
            lng += 0.01 * (rand - 0.5)
            body << "addWayPoint2('foo', #{lat}, #{lng});"
            
            res['Content-Type'] = "application/ecmascript"
            res.body = body.join('')
            session[:last] = [lat, lng]
          end
        end
                
      end
    end
  end
end
