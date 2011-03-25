#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
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
# = resourceHandler.rb
#
# == Description
#
# This file implements a resource handler servlet which searches for the respecitive
# files to serve in a list of directories.
#

require 'webrick'

module OMF
  module Common
    module Web
      # This class implements a resource handler servlet which searches for the respecitive
      # files to serve in a list of directories.
      class ResourceHandler  < WEBrick::HTTPServlet::FileHandler

        def initialize(server, options={}, default = WEBrick::Config::FileHandler)
          raise 'Missing :ResourcePath' unless options[:ResourcePath]
          super(server, "", options, default)
        end

        def set_filename(req, res)
          ex = nil
          resourcePath = @options[:ResourcePath]
          #puts ">>>>>>>>>>> Looking for #{req.path_info} in #{resourcePath.inspect}"
          path_info = req.path_info  # super is making with this value
          # crude attempt to find out if resource has file extension. If not add '.js'
          if path_info.slice(-5, 5).split('.').length == 1
            # no file extension
            path_info << '.js'
          end

          resourcePath.each do |dir|
            @root = dir
            begin
              req.path_info = path_info
              #puts "------------ #{req.path_info}"
              return super
            rescue Exception => ex
            end
          end
          MObject.error :web, "Can't find resource '#{req.path_info}' in '#{resourcePath.join(':')}'"
          raise ex
        end
      end

    end
  end
end
