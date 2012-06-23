require 'omf-web/widget/abstract_widget'
require 'omf-web/widget/text/maruku'

module OMF::Web::Widget

  # Supports widgets which displays text with 
  # potentially other widgets embedded.
  #
  class TextWidget < AbstractWidget
    
    def self.create_text_widget(type, wdescr)
      return self.new(wdescr)
    end
    
    def initialize(opts)
      opts = opts.dup # not sure why we may need to this. Is this hash used anywhere else?
      super opts      
      
      unless (source = opts[:source])
        raise "Missing 'source' option in '#{opts.describe}'"
      end      
      @content = OMF::Web::Widget::Text::Maruku.load_content(source)
      @opts[:title] = @content.attributes[:title] || opts[:title]
      @widgets = @content.attributes[:widgets] || []
    end
    
    def content()
      OMF::Web::Theme.require 'text_renderer'
      OMF::Web::Theme::TextRenderer.new(self, @content, @opts)
    end

    def collect_data_sources(ds_set)
      @widgets.each {|w| w.collect_data_sources(ds_set) }
      ds_set
    end

  end
end

