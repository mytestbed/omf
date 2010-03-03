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
            
            session_id = req.query['session'] || 'unknown'
            #MObject.debug(:web, "update for #{session_id}")
            unless session = @@sessions[session_id]
              session = @@sessions[session_id] = {:index => 0}
            end
            index = session[:index]
            
            unless (lout = GMapOutputter.instance)
            MObject.debug(:web, "NO OUTPUTTER")
              return
            end
            rem = lout.remaining_events(index)
            if (size = rem.size) == 0
              res.body = ''
              return
            end
            
            session[:index] = index + size
            arr = []
            rem.reverse_each do |m|
              arr << m[0]
            end
            res.body = arr.join
          end
        end
                
      end
    end
  end
end
