
require 'omf-web/tab/log/log_outputter'
require 'omf-web/tab/log/log_page'


module OMF::Web::Tab::Log
  class LogService < MObject

    def initialize(tab_id, opts)
      @tab_id = tab_id
    end
    
    def show(req, opts)
      puts "Service: #{opts.inspect}"
      id = req.params['id']
      [LogPage.new(opts).to_html, 'text/html']
    end
    
    def update(req, opts)
      id = req.params['id']
      if (!@shown || gID.nil?)
        body = "ERROR: Missing 'id' or expired session"
      else
        body = {:data => gd.data.to_a, :opts => gx[:gopts]}
      end
      # puts "DATA: #{body.inspect}"
      [body.to_json, "text/json"]
    end
  end # LogService   
 
        # def self.configure(server, options = {})
        # server.mount('/log/show', LogServlet, options)
    # server.mount('/log/update', LogUpdateServlet, options)
#       
    # server.addTab(VIEW, "/log/show", :name => 'Logs',
        # :title => "Real-time logs of experiment")
    # end
  
  # class LogUpdateServlet  < WEBrick::HTTPServlet::AbstractServlet
    # @@sessions = {}
#       
    # def do_GET(req, res)
      # opts = @options[0].dup
      # opts[:flash].clear
      # opts[:view] = :log
#         
      # session_id = req.query['session'] || 'unknown'
      # #MObject.debug(:web, "update for #{session_id}")
      # unless session = @@sessions[session_id]
        # session = @@sessions[session_id] = {:index => 0}
      # end
      # index = session[:index]
#         
      # unless (lout = LogOutputter.instance)
      # MObject.debug(:web, "NO OUTPUTTER")
        # return
      # end
      # rem = lout.remaining_events(index)
      # if (size = rem.size) == 0
        # res.body = ''
            # return
          # end
#             
          # session[:index] = index + size
          # arr = []
          # rem.reverse_each do |m|
            # arr << m[0]
          # end
          # res.body = arr.join
        # end
      # end
#         
#   
    # end
  # end
end # module
  