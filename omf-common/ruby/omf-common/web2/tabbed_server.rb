
require 'omf-common/mobject'
require 'erector'
require 'rack'
require 'omf-common/web2/page'
require 'omf-common/web2/multi_file'
require 'omf-common/web2/session_store'
require 'omf-common/web2/tab_mapper'

module OMF
  module Common
    module Web2
      
      # Start a web server supporting multiple services in a tabbed 
      # GUI style
      #
      # opts:
      #   :port => INT                   - Port to listen on [4000]
      #   :page_title => STRING          - Main title of web page
      #   :use_tabs => [:tabName, ...]   - Tabs to show and in which order [ALL]
      #   :static_dirs => [dirName, ...] - Name of directories to look for resources [.../htdocs, ./resource]
      #
      def self.start(opts)
        require 'rack'
        require 'rack/showexceptions'
        require 'thin'

        static_dirs = opts[:static_dirs] || ["#{File.dirname(__FILE__)}/../../../share/htdocs", "./resources"]
        
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
        
        s = ::Thin::Server.new('localhost', 4040) do
          use ::Rack::ShowExceptions
          use ::Rack::Lint
          
          map "/resource" do
#            run Rack::File.new("omf-common/share/htdocs")
            run OMF::Common::Web2::Rack::MultiFile.new(static_dirs)
          end
          map '/_ws' do
            require 'omf-common/web2/websocket_handler'
            run OMF::Common::Web2::WebsocketHandler.new # :backend => { :debug => true }
          end
          map '/_update' do
            require 'omf-common/web2/update_handler'
            run (updater ||= OMF::Common::Web2::UpdateHandler.new)
          end
          map "/" do    
            run(mapper ||= OMF::Common::Web2::TabMapper.new(opts))
          end
        end
        
        if (ssl_opts = opts[:ssl])
          b = s.backend
          b.ssl = true
          b.ssl_options = ssl_opts
        end
        s.start
          
      end
    
    
      
    end # Web2
  end # Common
end # OMF

if $0 == __FILE__
  class Foo
    def initialize(ctxt)
      
    end
    
    def show(req, popts)
      popts[:card_title] = 'Foo'
      [Page.new(popts), 'text/html']
    end
  end
  
  require 'omf-common/web2/tab/graph/oml_table'
  t1 = OMF::Common::OML::OmlTable.new('s1', [[:x], [:y]], :max_size => 20)
  Thread.new do
    i = 0
    while true
      begin
        i = i + 1 
        t1.add_row [i, rand]
        #puts t1.rows.join(' ')
        sleep 1
      rescue Exception => ex
        puts "ERROR: #{ex}"
      end
    end
  end
  
  
  require 'omf-common/web2/tab/graph/graph_service'
  i = 0
  gopts = {
    #:query => ms[:foo]....
    #:oml_endpoint => {:port => 3000},
    :data_source => t1,
    #:data_source => lambda do |g|      
      # i = i + 1 
      # [{:x => i, :y => rand}]
    # end,
    # :data_source_interval => 2, # call data source proc every 2 seconds
    :viz_type => 'line_chart',
    :viz_opts => {},
    :dynamic => true
  }
  OMF::Common::Web2::Graph.addGraph('Graph DS', gopts) do |g, rows|
    #puts "HIHHH #{rows.inspect}"
    data = rows.collect do |r|
      [r[:x], r[:y]]
    end
    [{:label => "AAA", :data => data}]
  end
  
  require 'omf-common/web2/tab/graph/oml_endpoint'
  ep = OMF::Common::OML::OmlEndpoint.new(3000)
  toml = OMF::Common::OML::OmlTable.new('oml', [[:x], [:y]], :max_size => 20)
  ep.on_new_stream() do |s|
    puts "New stream: #{s}"
    s.on_new_vector() do |v|
      #puts "New vector: #{v.to_a(true).join('|')}"      
      toml.add_row(v.select(:oml_ts, :value))
    end
  end
  ep.run()
  
    
  gopts2 = {
    #:query => ms[:foo]....
    :data_source => toml,
    :viz_type => 'line_chart',
    :viz_opts => {},
    :dynamic => true 
  }
  OMF::Common::Web2::Graph.addGraph('Graph OEP', gopts2) do |g, rows|
    puts "HIHHH #{rows.inspect}"
    data = rows.collect do |r|
      [r[:oml_ts], r[:value]]
    end
    [{:label => "AAA", :data => data}]
  end

  
  opts = {
    :sslNOT => {
      :cert_chain_file => "#{File.dirname(__FILE__)}/debug/server_chain.crt", 
      :private_key_file => "#{File.dirname(__FILE__)}/debug/server.key", 
      :verify_peer => false
    },
    
    :tabs => {
      :foo => {:name => 'Foo', :order => 1, :class => Foo},
      :goo => {:name => 'Goo', :order => 3}
    }
  }
  OMF::Common::Web2.start(opts)
end
      
        
