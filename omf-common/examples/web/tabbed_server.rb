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
# = tabbed_server.rb
#
# == Description
#

require 'optparse'
require 'omf-common/mobject'
require 'omf-common/web/webServer'
require 'omf-common/web/helpers'
require 'omf-common/oml/arel_remote'
#require 'omf-expctl/web/helpers'

class ViewHelper < OMF::Common::Web::ViewHelper

  def self.page_title
    $TITLE
  end
end


def startWebServer(opts)
  port = opts[:port]
  opts[:Logger] ||= MObject.logger('web')
  #opts[:DocumentRoot] ||= NodeHandler.WEB_ROOT()
  #opts[:AccessLog] ||= [[accLog, "%h \"%r\" %s %b"]]
  opts[:TabDir] ||= ['omf-common/web/tab']
  opts[:ResourceDir] ||= ['omf-common/share/htdocs']
  opts[:ViewHelperClass] = ViewHelper
  opts[:StartServerThread] = false
  opts[:ShowTabs] = [:graph3]
  
  OMF::Common::Web::start(port, opts) do |s|
    initGraphs(opts)
    
    trap("HUP") do # use 1 instead of "HUP" on Windows
      s.stop 
    end
  end
end

def initResultService(opts)
  url = opts[:serviceURL]
  adaptor = OMF::Common::OML::Arel::HttpServiceAdaptor.new(url) 

  ropts = {:name => opts[:repoName]}
  opts[:repo] = OMF::Common::OML::Arel::Repository.new(ropts, adaptor) 
end

def error(cat, msg)
  puts "ERROR(#{cat}): #{msg}"
end

def parseCommandLine(opts)
  op = OptionParser.new
  op.banner = "\nStart a web server with a tabbed UI\n\n" +
    "Usage: #{$0} [OPTIONS]\n"+
    "\t[OPTIONS] are any of the following:\n\n" 
  
  op.on("-d", "--debug", "Operate in debug mode [#{opts[:debug]}]") { 
    opts[:debug] = true 
  }
  
  op.on("-p", "--port INT", "Port for server to listen on [#{opts[:port]}]") {|p|
    opts[:port] = p.to_i
  }

  op.on("-r", "--repo-name STRING", "Name of repository [#{opts[:repoName]}]") {|p|
    opts[:repoName] = p
  }

  op.on("-s", "--service-url URL", "URL of the result2 AM service [#{opts[:serviceURL]}]") {|u|
    opts[:serviceURL] = u
  }
  # Parse the command line
  op.parse(ARGV)
end


opts = $DEF_OPTS.dup
parseCommandLine(opts)
initResultService(opts)
startWebServer(opts)
puts "done"
