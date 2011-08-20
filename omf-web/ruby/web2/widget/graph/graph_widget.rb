
require 'erector'

module OMF::Common::Web2; module Widget::Graph
  
  # Maintains the context for a particular graph rendering within a specific session.
  # It is primarily called upon maintaining communication withthe browser and will
  # create the necessary html and javascript code for that.
  #
  class GraphWidget < Erector::Widget
    
    attr_reader :name, :opts
    
    def initialize(widget_id, gd)
      @widget_id = widget_id
      @gd = gd
      @opts = gd.opts
      @data_source = @opts[:data_source]
      @name = @gd.name
      @js_uri = @gd.vizType # || DEF_VIS_TYPE # @opts[:gopts][:gtype] || 'matrix'
      @base_id = "g#{object_id.abs}"
      @base_el = "\##{@base_id}"
      
      @js_var_name = "oml_#{object_id.abs}"
      @js_func_name = 'OML.' + @js_uri.gsub("::", "_")

      @gopts = @gd.vizOpts.dup
      #@gopts['session'] = session_id
      # gopts['canvas'] = canvas if canvas
      # gopts['data'] = data()
      @gopts['base_el'] = @base_el
      
    end
    
    # A dynamic grph may open a web socket back to this service. Find the 
    # respective graph widget and hand it on.
    #
    def on_ws_open(ws)
      @ws = ws
      if @data_source
        @data_source.on_row_added(self) do |row|
          #puts "ROW: #{row.inspect}"
          update = [{:data => @data_source.rows}]
          ws.send_data update.to_json
        end
      end
    end
    
    def on_ws_close(ws)
      @ws = nil
      if @data_source
        # cancel callback
        @data_source.on_row_added(self)
      end
    end
    

    def content()
      div :id => @base_id, :class => "oml_#{@js_uri}" do
        #p @opts.inspect
        #p get_static_js
        javascript(%{  
          var l = L;        
          L.require('OML.#{@gd.vizType}', ['graph/#{@js_uri}'], function() {
            #{get_static_js}
            #{get_dynamic_js}        
          });
        })
      end
    end
    
    def get_static_js()
      if @data_source
        #@gopts[:data] = [{:data => @data_source.rows}]
        @gopts[:data] = @data_source.rows
      end
      "var #{@js_var_name} = new #{@js_func_name}(#{@gopts.to_json});"
    end
    
    def get_dynamic_js()
      return "" unless (dopts = @gd.opts[:dynamic])
      
      dopts = {} if dopts == true # :dynamic => true is valid option
      unless (updateInterval = dopts[:updateInterval]) 
        updateInterval = 3
      end 
      %{
        var ws#{@base_id};
        if (window.WebSocket) {
          var url = 'ws://' + window.location.host + '/_ws';
          var ws = ws#{@base_id} = new WebSocket(url);
          ws.onopen = function() {
            ws.send('id:#{@widget_id}');
          };
          ws.onmessage = function(evt) {
            // evt.data contains received string.
            var msg = eval(evt.data);
            //var data = msg['data'];
            //var opts = msg['opts'];
            var data = msg;
            //#{@js_var_name}.append(data);
            #{@js_var_name}.update(data);
          };
          ws.onclose = function() {
            var status = "onclose";
          };
          ws.onerror = function(evt) {
            var status = "onerror";
          };
        } else {
          require(['/resource/js/jquery.js'], function() {
            require(['/resource/js/jquery.periodicalupdater.js'], function() {
              $.PeriodicalUpdater('/_update?id=#{@widget_id}', {
                  method: 'get',          // method; get or post
                  data: '',                   // array of values to be passed to the page - e.g. {name: "John", greeting: "hello"}
                  minTimeout: #{updateInterval * 1000},       // starting value for the timeout in milliseconds
                  maxTimeout: #{4 * updateInterval * 1000},       // maximum length of time between requests
                  multiplier: 2,          // if set to 2, timerInterval will double each time the response hasn't changed (up to maxTimeout)
                  type: 'json',           // response type - text, xml, json, etc.  See $.ajax config options
                  maxCalls: 0,            // maximum number of calls. 0 = no limit.
                  autoStop: 0             // automatically stop requests after this many returns of the same data. 0 = disabled.
              }, function(reply) {
                  var data = reply['data'];
                  var opts = reply['opts'];
                  #{@js_var_name}.append(data);
              });
            });
          });
        }
      }
    end
  end # GraphWidget
  
end; end 
