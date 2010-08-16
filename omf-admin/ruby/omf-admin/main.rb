#
# Copyright (c) 2010 National ICT Australia (NICTA), Australia
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#

require 'omf-common/omfVersion'
require 'net/http'
require 'web/webServer'
require 'config'
require 'testbeds'
require 'nodes'
require 'uri'
require 'omf-common/servicecall'
require 'rexml/document'

DEFAULT_PORT=5454
@@OMF_VERSION = "OMF Administration Interface v.#{OMF::Common::VERSION(__FILE__)}"
puts @@OMF_VERSION

@@dummy=false
#Jabber::debug = true

@@config = AdminConfig.new

OMF::ServiceCall.add_domain(:type => :xmpp,
                            :uri => @@config.get[:communication][:xmppserver][:value],
                            :user => "omf-admin",
                            :password => "123")


@@testbeds = Testbeds.new
@@nodes = Nodes.new

@@currentTB = @@testbeds.getAll.first['name']

p @@nodes.getAll


port = DEFAULT_PORT
idx = ARGV.index("--port")
port = ARGV[idx+1] if !idx.nil? && !ARGV[idx+1].nil?

begin
  require 'web/helpers'
  OMF::Admin::Web::start(port,
  :DocumentRoot => ".",
  :TabDir => ["#{File.dirname(__FILE__)}/web/tab"],
  #:PublicHtml => OConfig[:ec_config][:repository][:path],
  :ResourceDir => @@config.get[:webinterface][:rdir][:value])
rescue Exception => ex
  puts "Cannot start webserver (#{ex})"
end 

loop{
  sleep 10
}
