


require 'maruku'
require 'maruku/ext/math'
require 'rexml/document'
require 'yaml'

MaRuKu::Globals[:html_math_engine] = 'ritex'

module OMF::Web::Widget::Text
  
  module Maruku
    
    # Fetch text and parse it
    #  
    def self.load_content(source)
      unless File.readable?(source)
        raise "Cannot read text file '#{source}'"
      end
      content = File.open(source).read
      ::Maruku.new(content)
    end
    
    class WidgetElement
      attr_reader :widget
      
      def initialize(wdescr)
        @wdescr = wdescr
        @widget = OMF::Web::Widget.create_widget(wdescr)
      end
      
      def to_html
        content = @widget.content
        puts content.inspect
        h = content.to_html
        if title = @widget.title
          h += "<div class='caption'>#{title}</div>"
        end
        ::REXML::Document.new("<div class='embedded'>#{h}</div>").root
      end
      
      def node_type
        :widget
      end
    end
    
    OpenMatch = /^\s*\{\{\{\s*(.*)$/
    CloseMatch = /(.*)\}\}\}/
    
    MaRuKu::In::Markdown::register_block_extension(
      :regexp  => OpenMatch,
      :handler => lambda { |doc, src, context|
        lines = []
          
        line = src.shift_line
        line =~ OpenMatch
        line = $1
        while line && !(line =~ CloseMatch)
          lines << line
          line = src.shift_line
        end
        lines << $1
        descr = YAML::load(lines.join("\n"))
        descr = OMF::Web::deep_symbolize_keys(descr)
        if (wdescr = descr[:widget])
          wel = WidgetElement.new(wdescr)
          context << wel
          (doc.attributes[:widgets] ||= []) << wel.widget
        else
          raise "Unknown embeddable '#{descr.inspect}'"
        end
        true
      }
    )
    
  end # module Maruku

end # OMF::Web::Widget::Text

# module MaRuKu::Out::HTML
# 
  # def to_html_viz
    # span = Element.new 'javascript'
    # span.attributes['class'] = 'maruku_section_number'
    # span << Text.new('Foooo')
    # add_ws  span
  # end
#   
# end