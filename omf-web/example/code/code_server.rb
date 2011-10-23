

require 'omf-web/tabbed_server'
require 'omf-web/widget/code'

# Add scripts
#

OMF::Web::Widget::Code.addCode('Main', :file => "#{File.dirname(__FILE__)}/code_server.rb") 



# Configure the web server
#
opts = {
  :sslNOT => {
    :cert_chain_file => "#{File.dirname(__FILE__)}/debug/server_chain.crt", 
    :private_key_file => "#{File.dirname(__FILE__)}/debug/server.key", 
    :verify_peer => false
  },
  :page_title => 'Code Tab Demo',
  :use_tabs => [:code]
  # :tabs => {
    # :foo => {:name => 'Foo', :order => 1, :class => Foo},
    # :goo => {:name => 'Goo', :order => 3}
  # }
}
OMF::Web.start(opts)
