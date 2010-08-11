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

DEFAULT_PORT=5454

@@config = AdminConfig.new
@@testbeds = Testbeds.new
@@nodes = Nodes.new

@@currentTB = @@testbeds.getAll.first['name']

begin
  require 'web/helpers'
  port = DEFAULT_PORT if !(port = @@config.get[:webinterface][:port][:value])
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
