require 'erector'

require 'omf-web/data_source_proxy'

module OMF::Web::Theme
  class AbstractPage < Erector::Widget
    
    
    depends_on :js, '/resource/vendor/jquery/jquery.js'
    #depends_on :js, '/resource/js/stacktrace.js'
    depends_on :js, '/resource/vendor/underscore/underscore.js'
    depends_on :js, '/resource/vendor/backbone/backbone.js'    
    depends_on :js, "/resource/js/require3.js"
  
    depends_on :script, %{
      L.baseURL = "/resource";
      OML = {
        data_sources: {}
      };
        
      var OHUB = {};
      _.extend(OHUB, Backbone.Events);
    }
    
    def initialize(opts)
      super opts
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
      
      dsh = collect_data_sources({})
      return if dsh.empty?
      
      js = dsh.collect do |ds, update_interval|
        render_data_source(ds, update_interval)
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
    
    def render_data_source(ds, update_interval)
      dsp = OMF::Web::DataSourceProxy.for_source(ds)
      dsp.reset()
      dsp.to_javascript(update_interval)
      
      # unless ds.kind_of?(OMF::OML::OmlTable)
        # raise "Expected OmlTable, but got '#{ds.class}::#{ds}'"
      # end
      # name = "ds#{ds.object_id}"
      # %{
        # OML.data_sources['#{name}'] = new OML.data_source('#{name}', 
                                                          # '/_update?sid=#{Thread.current["sessionID"]}&did=#{name}',
                                                          # #{update_interval},
                                                          # #{ds.schema.to_json},
                                                          # #{ds.rows.to_json});
      # }
    end

    def collect_data_sources(dsa)
      dsa
    end
      
    
  
    def to_html(opts = {})
      b = super
      e = render_externals << render_data_sources
     
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
  