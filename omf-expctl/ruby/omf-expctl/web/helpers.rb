require 'coderay'
require 'ftools'
require 'net/http'

module OMF
  module ExperimentController
    module Web
      class ViewHelper

        EXP_ID_URL = 'http://console.outdoor.orbit-lab.org:4000/exp_id'
        
        @@exp_id = nil
        
        def self.exp_id
          "outdoor-#{Experiment.ID}"
        end
        
        def self.javascript_include_tag(name)
          case name.to_s
            when 'defaults'
              s = javascript_include_file 'prototype.js'
              s = s + javascript_include_file('effects.js')
              s = s + javascript_include_file('dragdrop.js')
              s = s + javascript_include_file('controls.js')
              s = s + javascript_include_file('application.js')
              s
          else
            javascript_include_file "#{name}.js"
          end
        end

        def self.javascript_include_file(name)
          "<script src='/resource/js/#{name}' type='text/javascript'></script>"
        end

        def self.stylesheet_link_tag(name)
          stylesheet_link_file("#{name}.css")
        end
        
        def self.stylesheet_link_file(name)
          "<link href='/resource/css/#{name}' media='screen' rel='Stylesheet type='text/css'>"
        end
      

        def self.render(opts)
          if partial = opts[:partial]
            MabRenderer.render_partial(partial)
          else
            "====UNKNONW RENDER(#{opts.inspect})===="
          end
        end
      
        def self.render_content()
          MabRenderer.render_content
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
      
        @mime2crType = {
          '/text/ruby' => :ruby,
          '/text/xml' => :xml
        }
        
        def self.render_code(content, mimeType = '/text/ruby')
          type = @mime2crType[mimeType] || ''
          tokens = CodeRay.scan content, type
          tokens.html :line_numbers => :inline, :tab_width => 2, :wrap => :div
        end
      
        
    #    def self.flash(*args)
    #      
    #    end
    
        def self.content_for_layout
        end
      end
    end
  end
end
