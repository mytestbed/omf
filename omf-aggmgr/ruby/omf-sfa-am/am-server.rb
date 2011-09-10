require 'rubygems'
require 'rack'
require 'rack/showexceptions'
require 'thin'
require 'rack/rpc'


require 'omf-sfa-am/am_rpc_service'

module AMTest
  
  def self.start(opts)

    s = ::Thin::Server.new('0.0.0.0', opts[:port] ||= 8001) do
#      use ::Rack::ShowExceptions
#      use ::Rack::Lint

        use Rack::RPC::Endpoint, OMF::SFA::AM::AMService.new, :path => '/RPC2' 
      
#      map ::Rack::RPC::Endpoint::DEFAULT_PATH do    
      # map '/' do    
        # run ::Rack::RPC::Endpoint.new(nil, OMF::SFA::AM::AMService.new, :path => '/')
      # end
      # map '/RPC2' do    
        # run ::Rack::RPC::Endpoint.new(nil, OMF::SFA::AM::AMService.new, :path => '')
      # end
    end
    
    if (ssl_opts = opts[:ssl])
      b = s.backend
      b.ssl = true
      b.ssl_options = ssl_opts
    end
    s.start
      
  end

end

# Configure the web server
#
opts = {
  :port => 8001,
  :ssl => {
    :cert_chain_file => File.expand_path("~/.gcf/am-cert.pem"), 
    :private_key_file => File.expand_path("~/.gcf/am-key.pem"), 
    :verify_peer => true
  },
}
AMTest.start(opts)
