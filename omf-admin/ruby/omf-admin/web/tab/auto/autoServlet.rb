require 'web/renderer'
require 'web/helpers'
include OMF::Admin::Web

#
# A servlet to autodetect nodes
#
module OMF
  module Admin
    module Web
      module Auto
        VIEW = :auto
        
        @@scripts = []
        
        def self.configure(server, options = {})
          opts = options.dup
          opts[:scripts] = @@scripts
          server.mount('/auto', AutoServlet, opts)
          server.addTab(VIEW, "/auto", :name => 'Auto-Detect', 
              :title => "Auto-detect new nodes and add them to the testbed")

        end

        def self.addScript(opts)
          @@scripts << opts
        end

        class AutoServlet < WEBrick::HTTPServlet::AbstractServlet
          
          @@auto_nodes = []
          @@macvendor = eval(File.open('macvendor.rb').read)
          
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
            
            readSyslog
            
            opts[:auto_nodes] = @@auto_nodes
            res.body = MabRenderer.render('auto', opts)
            @@auto_nodes = []
          end
          
          def readSyslog
            syslog0 = "/var/log/syslog"
            syslog1 = "/var/log/syslog.1"
            discover = `grep DHCPDISCOVER #{syslog1} #{syslog0} | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`.split("\n")
            discover.uniq!
            # remove MAC addresses of nodes already in the inventory
            known = @@nodes.getAll.collect{|n| n['control_mac']}
            if !known.nil?
              discover = discover - known
            end
            # find the Vendor IDs of the remaining MACs
            discover.each{|m|
              vendorID = m[0..7].gsub(':','-').upcase
              vendor = "unknown"
              @@macvendor.each{|v,n|
                vendor=n if v==vendorID
              }
              @@auto_nodes << ["#{m}", "#{vendor}"]
            }
          end
        end
      end
    end
  end
end
