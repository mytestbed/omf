require 'rubygems'
require 'rack'
require 'rack/showexceptions'
require 'thin'
require 'rack/rpc'
    


module AMTest
  
  def self.start(opts)

    
    s = ::Thin::Server.new('0.0.0.0', opts[:port] ||= 8001) do
#      use ::Rack::ShowExceptions
#      use ::Rack::Lint
      
      autoload :Service, 'am_rpc_service'
      run ::Rack::RPC::Endpoint.new(nil, Service.new, :path => '/')
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
