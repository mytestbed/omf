require 'rubygems'
require 'rack'
require 'rack/showexceptions'
require 'thin'
require 'thin/runner'
require 'omf-common/mobject2'
require 'omf-common/load_yaml'

require 'omf-web/runner'


OMF::Common::Loggable.init_log 'omf_web'
#config = OMF::Common::YAML.load('omf-web', :path => [File.dirname(__FILE__) + '/../../etc/omf-web/omf_web.yml'])[:omf_web]

# Add additional cert roots. Should really come from the config file
# trusted_cert_file = File.expand_path('~/.gcf/trusted_roots/CATedCACerts.pem')
# trusted_cert = OpenSSL::X509::Certificate.new(File.read(trusted_cert_file))
# OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.add_cert(trusted_cert)

# Configure the web server
#
opts = {
  :port => 4040,
  :sslXXX => {
    :cert_file => File.expand_path("~/.omf/my-cert.pem"), 
    :key_file => File.expand_path("~/.omf/my-key.pem"), 
    :verify_peer => true
  },
  :rackup => File.dirname(__FILE__) + '/config.ru'
}

Thin::Logging.debug = true
OMF::Web::Runner.new(ARGV, opts).run!
