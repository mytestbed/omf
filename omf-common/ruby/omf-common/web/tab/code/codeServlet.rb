
require 'omf-common/web/renderer'
require 'omf-common/web/helpers'
include OMF::Common::Web

#
# A servlet to display scripts
#
module OMF
  module Common
    module Web
      module Code
        VIEW = :code
        
        @@scripts = []
        
        def self.configure(server, options = {})
          opts = options.dup
          opts[:scripts] = @@scripts
          server.mount('/code/show', CodeServlet, opts)
          server.addTab(VIEW, "/code/show", :name => 'Scripts', 
              :title => "Browse all scripts involved in this experiment")

          if (onConfig = opts[:on_configure])
            onConfig.call(self)
          end
#          OConfig.add_observer() { |action, opts|
#            if action == :load
#              self.addScript(opts)
#            end 
#          }
#          OConfig.getLoadHistory.each do |sopts| addScript(sopts) end
        end

        def self.addScript(opts)
          @@scripts << opts
        end

        class CodeServlet < WEBrick::HTTPServlet::AbstractServlet

          def do_GET(req, res)
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = VIEW
            opts[:show_file] = nil
            if i = req.query['id'] || 0
              opts[:show_file_id] = i.to_i
            else
              opts[:flash][:alert] = "Missing 'id'"
            end
            
            #puts "OPTS >>>> #{opts.inspect}"
  
            #MObject.debug :web_code_servlet, "OPTS: #{opts.inspect}"
            #opts[:flash][:notice] = opts.inspect
            res['Content-Type'] = 'text/html'
            res.body = MabRenderer.render('show', opts)
          end
        end
      end
    end
  end
end
