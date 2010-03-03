require 'webrick'
require 'webrick/httputils'
require 'log4r/outputter/outputter'
require 'log4r/formatter/formatter'


module OMF
  module ExperimentController
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
            res.body = MabRenderer.render('log/show', opts, ViewHelper)
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
  
        
        class LogOutputter < Log4r::Outputter
          @@instance = nil
          
          def self.instance
            @@instance
          end
          
          def initialize(name = 'remote', hash={})
            super(name, hash)
            self.formatter = (hash[:formatter] or hash['formatter'] or WebFormatter.new)
  
            @event = []
            @@instance = self
          end
          
          def remaining_events(index)
            @event[index .. -1]
          end
        
          def format(logevent)
            # @formatter is guaranteed to be DefaultFormatter if no Formatter
            # was specified
            @event << [@formatter.format(logevent), logevent]
            #puts ">>>>>>>>>>>>>>>> #{logevent.inspect}"
          end
  
        end
  
        class WebFormatter < Log4r::BasicFormatter
          def format(event)
            lname = Log4r::LNAMES[event.level]
            fs = "<tr class=\"log_#{lname.downcase}\"><td class='%s'>%s</td><td class='name'>%s"
            buff = sprintf(fs, lname.downcase, lname, event.name)
            buff += (event.tracer.nil? ? "" : "(#{event.tracer[0]})") + ":</td>"
            data = format_object(event.data).gsub(/</, '&lt;')
            buff += sprintf("<td class='data'>%*s</td></tr>", Log4r::MaxLevelLength, data)
            buff
          end
        end
      end
    end
  end
end
