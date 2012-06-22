require 'omf-web/theme/abstract_page'

module OMF::Web::Theme

  class DataRenderer < Erector::Widget
    
    def initialize(widget, opts)
      super opts
      @base_id = widget.dom_id
      @js_class = opts[:js_class]
      @js_url = opts[:js_url]
      @wopts = opts.dup
    end    

    def content()
      div :id => @base_id, :class => "#{@js_class.gsub('.', '_').downcase}" do
        javascript(%{
          L.require('\##@js_class', '#@js_url', function() {
            OML.widgets.#{@base_id} = new #{@js_class}(#{@wopts.to_json});
          });
        })
      end
    end
    
  end
end