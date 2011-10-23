require 'rubygems'
require 'rack'
require 'rack/showexceptions'
require 'thin'
require 'rack/rpc'
require 'omf-common/mobject2'
require 'omf-common/load_yaml'


require 'omf-sfa/am/am_rpc_service'

module AMTest
  
  RPC_URL = '/RPC2'
  
  def self.start(opts)

    s = ::Thin::Server.new('0.0.0.0', opts[:port] ||= 8001) do
#      use ::Rack::ShowExceptions
      use ::Rack::Lint

      map RPC_URL do    
        run ::Rack::RPC::Endpoint.new(nil, OMF::SFA::AM::AMService.new, :path => '')        
      end
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
    #:verify_peer => true
    :verify_peer => true
  },
}

OMF::Common::Loggable.init_log 'am_server'
config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../../etc/omf-sfa'])[:omf_sfa_am]

#as = OMF::SFA::AM::AMService.new
#as.class.rpc
config[:endpoints].each do |ep|
  case type = ep.delete(:type).to_sym
  when :xmlrpc
    AMTest.start(opts)
  else   
    raise "Unknown endpoint type '#{type}'"
  end
end


#
