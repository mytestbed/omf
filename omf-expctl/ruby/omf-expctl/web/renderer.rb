
require 'rubygems'
#require 'util/mobject'
require 'markaby'

module OMF
  module ExperimentController
    module Web

      class MabRenderer
        #@@partial_dir = '../repository/views'
        @@partial_dir = "#{File.dirname(__FILE__)}/tab"

        def self.render(name, assigns = {}, helpers = nil)
          return unless content = read_content('shared/application')
          builder = Markaby::Builder.new(assigns, helpers)
          Thread.current[:MabRenderer] = {
            :builder => builder, :content => name
          }

          MObject.debug :renderer, "Rendering #{name}"
          return builder.capture_string(content)
          #return builder.to_s
          #t = Markaby::Template.new(content)
          #t.render(assigns, helpers)
        end
        
        def self.render_content()
          p = Thread.current[:MabRenderer][:content]
          return unless content = read_content(p)          
          builder = Thread.current[:MabRenderer][:builder]
          MObject.debug :renderer, "Rendering #{p}"
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
          MObject.debug :renderer, "Rendering #{path}"
          return builder.capture_string(content)
        end
        
        def self.read_content(name)
          fname = "#{@@partial_dir}/#{name}.mab"
          unless File.readable?(fname)
            MObject.error(:mab_renderer, "Can't find mab file for '#{name}' in '#{fname}'.")
            return nil
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
  include OMF::ExperimentController::Web
  puts MabRenderer.render('application', {:params => {}, :flash => {}}, ViewHelper)
end
