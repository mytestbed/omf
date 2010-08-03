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
require 'coderay'
require 'ftools'
require 'net/http'
require 'web/renderer'

module OMF
  module Admin
    module Web
      class ViewHelper

        def self.javascript_include_tag(name, opts = {})
          case name.to_s
            when 'defaults'
              s = javascript_include_file 'prototype.js'
              s = s + javascript_include_file('effects.js')
              s = s + javascript_include_file('dragdrop.js')
              s = s + javascript_include_file('controls.js')
              s = s + javascript_include_file('application.js')
              s
          else
            javascript_include_file "#{name}.js", opts
          end
        end

        def self.javascript_include_file(name, opts = {})
          unless name =~ /http:\/\//
            res_dir = opts[:res_dir] || 'js'
            name = "/resource/#{res_dir}/#{name}"
          end
          if opts[:ie_only]
            "<!--[if IE]><script src='#{name}' type='text/javascript'></script><![endif]-->"
          else
            "<script src='#{name}' type='text/javascript'></script>"
          end
        end

        def self.stylesheet_link_tag(name)
          stylesheet_link_file("#{name}.css")
        end
        
        def self.stylesheet_link_file(name)
          "<link href='/resource/css/#{name}' media='screen' rel='Stylesheet type='text/css'>"
        end
      

        def self.render(opts)
          if partial = opts[:partial]
            OMF::Admin::Web::MabRenderer.render_partial(partial)
          else
            "====UNKNONW RENDER(#{opts.inspect})===="
          end
        end
      
        def self.render_content()
          OMF::Admin::Web::MabRenderer.render_content
        end
        
        def self.render_code_file(fname)
          ## HACK!!!!
          path = "omf_ext/testing/#{fname}"
          if File.readable?(path)
            render_code File.new(path).read
          else
            "Can't find #{path}"
          end
#          begin
#          unless File.readable?(path)
#            #MObject.error(:web_helper, "Can't find code file '#{path}'.")
#            "Can't find code file '#{path}'."
#            return 
#        end
#    rescue => ex
#      puts ">>>>>>>>>>>>>> #{ex}"
#      exit
#      end
##          render_code File.new(fname).read
#          
#          File.readable?(path).to_s

#          render_code %{
#  require '#{fname}'
#  require '#{path}'  
#  require '#{File.readable?(path)}'  
#            
#  puts "No way"
#          }
        end
      
        @@mime2crType = {
          '/text/ruby' => :ruby,
          '/text/xml' => :xml
        }
        
        def self.render_code(content, mimeType = '/text/ruby')
          #puts ">>>>RENDER_CODE>> #{content.length}"
          type = @@mime2crType[mimeType] || ''
          #begin
            tokens = CodeRay.scan content, type
            tokens.html :line_numbers => :inline, :tab_width => 2, :wrap => :div
          #rescue Exception => ex
          #  puts ">>>> ERORRO: #{ex} #{ex.backtrace}"
          #end
          #puts "<<<<< END OF RENDER CODE"
        end
      
        def self.content_for_layout
        end
        
      end
    end
  end
end
