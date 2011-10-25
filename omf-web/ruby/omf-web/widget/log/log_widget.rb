
require 'erector'
require 'omf-web/session_store'

module OMF::Web::Widget::Log
  
  # Maintains the context for a particular log rendering within a specific session.
  # It is primarily called upon maintaining communication with the browser and will
  # create the necessary html and javascript code for that.
  #
  class LogWidget < Erector::Widget
    
    # def self.[](wid, opts = {})
      # w = nil
      # if wid
        # w = OMF::Web::SessionStore[wid]
      # end
      # unless w
        # w = self.new(opts)
        # puts ">>>> Creating new log widget #{w.widget_id}"
#         
      # end
      # w
    # end
    
    depends_on :css, "/resource/css/log.css"
    #depends_on :js, "/resource/css/log.css"    
    
    attr_reader :name, :widget_id, :opts
    
    def initialize(opts = {})
      @widget_id = "w#{object_id}"
      OMF::Web::SessionStore[@widget_id] = self
      @opts = opts
      @base_id = "g#{object_id.abs}"
      @base_el = "\##{@base_id}"
      
      @js_var_name = "oml_#{object_id.abs}"
      @js_func_name = 'OML.log_table'
      
    end
    
    # A dynamic grph may open a web socket back to this service. Find the 
    # respective graph widget and hand it on.
    #
    def on_ws_open(ws)
      #puts ">>>> ON_WS_OPEN"
      # begin
        # data = cs.describe
        # #puts "SENDING '#{data.to_json}'"
        # ws.send_data data.to_json
        # #r = {'a' =>  2}; ws.send_data r.to_json              
      # rescue Exception => ex
        # warn ex
      # end
    end
    
    def on_ws_close(ws)
      @ws = nil
    end
    
    # Called when log is dynamic and browser doesn't support web sockets
    #
    #
    def on_update(req)
      #{:data => _data(), :opts => {}}
      
      [{:data => {}, :opts => {}}.to_json, "text/json"]
    end
    
    def _data()
      data = []
      if @data_source
        data = @data_source.describe
      end
    end

    def content()
      div :id => @base_id, :class => "oml_log" do
        javascript(%{  
          L.require('\##{@js_func_name}', 'log/table.js', function() {
            #{get_static_js}
            #{get_dynamic_js}        
          });
        })
      end
    end
    
    def get_static_js()
      # @gopts[:data] = _data()
      # "var #{@js_var_name} = new #{@js_func_name}(#{@gopts.to_json});"
      gopts = {:base_el => @base_id}
      "var #{@js_var_name} = new #{@js_func_name}(#{gopts.to_json});"
    end
    
    def get_dynamic_js()
      dopts = @opts[:dynamic] || true
      dopts = {} if dopts == true # :dynamic => true is valid option
      unless (updateInterval = dopts[:updateInterval]) 
        updateInterval = 3
      end 
      res = <<END_OF_JS
        var ws#{@base_id};
        //if (window.WebSocket) {
        if (false) {
          var url = 'ws://' + window.location.host + '/_ws';
          var ws = ws#{@base_id} = new WebSocket(url);
          ws.onopen = function() {
            ws.send('id:#{@widget_id}');
          };
          ws.onmessage = function(evt) {
            // evt.data contains received string.
            var msg = jQuery.parseJSON(evt.data);
            var data = msg;
            #{@js_var_name}.append(data);
          };
          ws.onclose = function() {
            var status = "onclose";
          };
          ws.onerror = function(evt) {
            var status = "onerror";
          };
        } else {
          L.require(['jquery.js', '/resource/js/jquery.periodicalupdater.js'], function() {
              $.PeriodicalUpdater('/_update?sid=#{Thread.current["sessionID"]}&wid=#{@widget_id}', {
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
                  #{@js_var_name}.update(data);  // right now we are sending the entire graph
              });
          });
        }
END_OF_JS
    end


    
  end # GraphWidget
  
end

