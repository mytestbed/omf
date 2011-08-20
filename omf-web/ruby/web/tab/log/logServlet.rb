require 'webrick'
require 'webrick/httputils'
require 'omf-common/web/tab/log/logOutputter'


module OMF
  module Common
    module Web
      module Log
        VIEW = :log
        def self.configure(server, options = {})
          server.mount('/log/show', LogServlet, options)
          server.mount('/log/update', LogUpdateServlet, options)
          
          server.addTab(VIEW, "/log/show", :name => 'Logs',
              :title => "Real-time logs of experiment")
        end

        class LogServlet  < WEBrick::HTTPServlet::AbstractServlet
          
   
          def do_GET(req, res)
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = VIEW
  
            opts[:session_id] = "sess#{(rand * 10000000).to_i}"
            res.body = MabRenderer.render('log/show', opts)
          end
        end
        
        class LogUpdateServlet  < WEBrick::HTTPServlet::AbstractServlet
          @@sessions = {}
          
          def do_GET(req, res)
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = :log
            
            session_id = req.query['session'] || 'unknown'
            #MObject.debug(:web, "update for #{session_id}")
            unless session = @@sessions[session_id]
              session = @@sessions[session_id] = {:index => 0}
            end
            index = session[:index]
            
            unless (lout = LogOutputter.instance)
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
        
        class LogUpdateProxyServlet  < WEBrick::HTTPServlet::AbstractServlet
          
          def do_GET(req, res)
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = :log
            
            session_id = req.query['session'] || 'unknown'
            u = "http://console.outdoor.orbit-lab.org:4000/log/update?session=#{session_id}"
            response = Net::HTTP.get_response(URI.parse(u))
            if response.code.to_i == 200
              res.body = response.body
            else
              res.body = ''            
            end
            
          end
        end
  
      end
    end
  end
end
