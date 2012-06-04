require 'erector'

require 'omf-web/data_source_proxy'

module OMF::Web::Theme
  class AbstractPage < Erector::Widget
    
    depends_on :js,  '/resource/vendor/stacktrace/stacktrace.js'
    depends_on :js, '/resource/vendor/jquery/jquery.js'
    #depends_on :js, '/resource/js/stacktrace.js'
    depends_on :js, '/resource/vendor/underscore/underscore.js'
    depends_on :js, '/resource/vendor/backbone/backbone.js'    
    depends_on :js, "/resource/js/require3.js"
  
    depends_on :script, %{
      L.baseURL = "/resource";
      OML = {
        data_sources: {},
        widgets: {},
        
        show_widget: function(prefix, index, widget_id) {
          $('.' + prefix).hide();
          $('#' + prefix + '_' + index).show();
          
          var current = $('#' + prefix + '_l_' + index);
          current.addClass('current');
          current.siblings().removeClass('current');
           
          //s.trigger('activate');
          OML.widgets[widget_id].resize().update();
        }
      };
        
      var OHUB = {};
      _.extend(OHUB, Backbone.Events);
      
      $(window).resize(function(x) {
        OHUB.trigger('window.resize', {});
      });      
    }
    
    def initialize(opts)
      #puts ">>>>> #{opts.keys.inspect}"
      super opts
      @opts = opts
    end
    
    def render_flash
      return unless @flash
      if @flash[:notice] 
        div :class => 'flash_notice flash' do
          text @flash[:notice]
        end
      end
      if @flash[:alert]
        div :class => 'flash_alert flash' do
          a = @flash[:alert]
          if a.kind_of? Array
            ul do
              a.each do |t| li t end
            end
          else
            text a
          end
        end
      end
    end # render_flesh
    
    def render_data_sources
      require 'omf-oml/table'
      require 'set'
      
      dsh = collect_data_sources(Set.new)
      return if dsh.empty?
      
      js = dsh.to_a.collect do |ds|
        render_data_source(ds)
      end
      #puts "JS>>>> #{js.join("/n")}"
      # Calling 'javascript' doesn't seem to work here. No idea why, so let's do it by hand
      %{
        <script src='/resource/js/data_source.js' type="text/javascript"></script>        
        <script type="text/javascript">
          // <![CDATA[
            #{js.join("\n")}
          // ]]>
        </script>
      }
    end
    
    def render_data_source(ds, update_interval = -1)
      dspa = OMF::Web::DataSourceProxy.for_source(ds)
      dspa.collect do |dsp|
        dsp.reset()
        dsp.to_javascript(update_interval)
      end.join("\n")
    end
    
    def render_additional_headers
      #"\n\n<link href='/resource/css/incoming.css' media='all' rel='stylesheet' type='text/css' />\n"
    end

    def collect_data_sources(dsa)
      dsa
    end
  
    def to_html(opts = {})
      b = super
      e = render_externals << render_additional_headers << render_data_sources
      r = Erector.inline do
        instruct
        html do
          head do
            text! e
          end
          body do
            text! b
          end
        end
      end
      r.to_html(opts)  
    end
  end # class AbstractPage
end # OMF::Web::Theme
  