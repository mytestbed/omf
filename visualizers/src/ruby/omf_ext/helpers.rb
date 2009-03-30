require 'coderay'

module OMF
  module ExperimentController
    module Web
      class ViewHelper

        def self.javascript_include_tag(name)
          case name.to_s
            when 'defaults'
              javascript_include_file 'prototype.js'
              javascript_include_file 'effects.js'
              javascript_include_file 'dragdrop.js'
              javascript_include_file 'controls.js'
              javascript_include_file 'application.js'
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
          render_code %{
  require '#{fname}'
            
  puts "No way"
          }
        end
      
        def self.render_code(content)
          #type = CodeRay::FileType[name]
 
          tokens = CodeRay.scan content, :ruby
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
