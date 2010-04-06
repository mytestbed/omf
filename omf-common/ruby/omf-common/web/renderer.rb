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

require 'rubygems'
require 'markaby'

module OMF
  module Common
    module Web

      class MabRenderer
        #@@partial_dir = '../repository/views'
        @@partial_dir = "#{File.dirname(__FILE__)}/tab"

        def self.render(name, assigns = {}, helpers = nil)
          builder = Markaby::Builder.new(assigns, helpers)
          Thread.current[:MabRenderer] = {
            :builder => builder, :content => name, :opts => assigns
          }
          return unless content = read_content('shared/application')

          #MObject.debug :renderer, "Rendering #{name}"
          return builder.capture_string(content)
        end
        
        def self.render_content()
          p = Thread.current[:MabRenderer][:content]
          return unless content = read_content(p)          
          builder = Thread.current[:MabRenderer][:builder]
          #MObject.debug :renderer, "Rendering #{p}"
          return builder.capture_string(content)
        end
        
        def self.render_partial(path)
          comp, name = path.split('/')
          if name.nil?
            p = "layout/_#{comp}"
          else
            p = "#{comp}/_#{name}"
          end
          return unless content = read_content(p)          
          builder = Thread.current[:MabRenderer][:builder]
          #MObject.debug :renderer, "Rendering #{path}"
          return builder.capture_string(content)
        end
        
        def self.read_content(name)
          view_dir = Thread.current[:MabRenderer][:opts][:view_dir]
          #fname = "#{@@partial_dir}/#{name}.mab"
          fname = "#{view_dir}/#{name}.mab"
          unless File.readable?(fname)
            view_dir = Thread.current[:MabRenderer][:opts][:common_view_dir]
            fname = "#{view_dir}/#{name}.mab"
            unless File.readable?(fname)
              MObject.error(:mab_renderer, "Can't find mab file for '#{name}' in '#{fname}'.")
              raise "FFFF #{Thread.current[:MabRenderer][:opts].inspect}"
              return nil
            end
          end
          return File.new(fname).read
        end
      end
    end
  end
end


# Extend Markaby's builder with a capture from string
#
module Markaby
  class Builder
    def capture_string(str)
      @streams.push(builder.target = [])
      @builder.level += 1
      #puts ">>>> #{str}"
      str = instance_eval(str)
      str = @streams.last.join if @streams.last.any?
      @streams.pop
      @builder.level -= 1
      builder.target = @streams.last
      str
    end
  end
end


if __FILE__ == $0
  require 'omf_ext/helpers'
  include OMF::Common::Web
  puts MabRenderer.render('application', {:params => {}, :flash => {}}, ViewHelper)
end
