

require 'erector'
require 'rack'
require 'omf_web'
require 'omf-web/rack/multi_file'
require 'omf-web/session_store'
require 'omf-web/rack/tab_mapper'
require 'omf-web/theme/theme_manager'

module OMF::Web
      
  # Start a web server supporting multiple services in a tabbed 
  # GUI style
  #
  # opts:
  #   :server => STRING              - Server address to bind to [0.0.0.0]
  #   :port => INT                   - Port to listen on [4000]
  #   :page_title => STRING          - Main title of web page
  #   :use_tabs => [:tabName, ...]   - Tabs to show and in which order [ALL]
  #   :static_dirs => [dirName, ...] - Name of directories to look for resources [.../htdocs, ./resource]
  #
  def self.start(opts)
    require 'rack'
    require 'rack/showexceptions'
    require 'thin'
    
    OMF::Web::Theme.theme = opts[:theme]
    OMF::Web::Theme.require 'page'


    static_dirs = opts[:static_dirs] || ["#{File.dirname(__FILE__)}/../../share/htdocs", "./resources"]
    
    # app = ::Rack::Builder.new do 
      # use ::Rack::ShowExceptions
      # use ::Rack::Lint
#           
      # map "/resource" do
        # run OMF::Common::Web2::Rack::MultiFile.new(static_dirs)
      # end
      # map "/" do    
        # run OMF::Common::Web2::TabMapper.new(opts)
      # end
    # end
    # port = opts[:port] || 4000
    # ::Rack::Handler::Thin.run(app, :Port => port)
            
    #   Older versions of EM have bug that prevent to
    #   clearing connection inactivity once it's set.
    #   This one will set connection timeout to 0 at
    #   default, so there will be no need to overwrite it.
    #   Be aware that this will also change inactivity
    #   timeout for "normal" connection, so it will be
    #   easy to make DoS attack.
    #
    if EM::VERSION < "1.0.0"
      begin
        old_verbose, $VERBOSE = $VERBOSE, nil
        ::Thin::Server.const_set 'DEFAULT_TIMEOUT', 0
      ensure
        $VERBOSE = old_verbose
      end
    end
    
    server = opts[:server] || '0.0.0.0'
    port = opts[:port] ? opts[:port] : 4040
    s = ::Thin::Server.new(server, port) do
      use ::Rack::ShowExceptions
      use ::Rack::Lint
      
      map "/resource" do
#            run Rack::File.new("omf-common/share/htdocs")
        run OMF::Web::Rack::MultiFile.new(static_dirs)
      end
      begin
        map '/_ws' do
          require 'omf-web/rack/websocket_handler'
          run OMF::Web::Rack::WebsocketHandler.new # :backend => { :debug => true }
        end
      rescue Exception => ex
        # Report that we don't have web socket support
      end
      map '/_update' do
        require 'omf-web/rack/update_handler'
        run (updater ||= OMF::Web::Rack::UpdateHandler.new)
      end
      map "/" do    
        run(mapper ||= OMF::Web::Rack::TabMapper.new(opts))
      end
    end
    
    if (ssl_opts = opts[:ssl])
      b = s.backend
      b.ssl = true
      b.ssl_options = ssl_opts
    end
    s.start
      
  end

end # module

      
        
