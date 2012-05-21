require 'omf-web/widget/abstract_widget'

module OMF::Web::Widget

  # Supports widgets which visualize the content of a +Table+
  # which may also dynamically change.
  #
  class AbstractDataWidget < AbstractWidget
    #depends_on :css, "/resource/css/graph.css"

    attr_reader :name, :opts


    # opts
    #   :data_sources .. Either a single table, or a hash of 'name' => table.
    #   :js_class .. Javascript class used for visualizing data
    #   :wopts .. options sent to the javascript instance
    #   :js_url .. URL where +jsVizClass+ can be loaded from
    #   :dynamic .. update the widget when the data_table is changing
    #     :updateInterval .. if web sockets aren't used, check every :updateInterval sec [3]
    #
    def initialize(opts = {})
      super opts
      @wopts = (opts[:wopts] || {}).dup
      if (ds = @wopts.delete(:data_source))
        # single source
        @data_sources = {:default => ds}
      end
      unless @data_sources ||= @wopts.delete(:data_sources)
        raise "Missing option ':data_sources' for widget '#@name'"
      end
      unless @data_sources.kind_of? Hash
        @data_sources = {:default => @data_sources}
      end
      @js_class = opts[:js_class]
      @js_url = opts[:js_url]

      @base_id = "w#{object_id.abs}"
      @base_el = "\##{@base_id}"
      @wopts['base_el'] = @base_el

      @js_var_name = "oml_#{object_id.abs}"
      #@js_func_name = 'OML.' + @js_url.gsub("::", "_")

      #@dynamic = opts.delete(:dynamic)


    end

    # A dynamic widget may open a web socket back to this service. Connect
    # to the respective table and feed back any changes.
    #
    # BUG ALERT: We send the entire content of the data table initially and only
    # start monitoring the table for new stuff when the web socket connects. Any
    # data added in between is not covered.
    #
    def on_ws_open(ws)
      #puts ">>>> ON_WS_OPEN"
      @ws = ws
      @data_sources.each do |name, table|
        table.on_row_added(self.object_id) do |row|
          begin
            # may want to queue events to group events into larger messages
            msg = [{:stream => name, :events => [row]}]
            ws.send_data msg.to_json
          rescue Exception => ex
            warn ex
          end
        end
      end
    end

    def on_ws_close(ws)
      @ws = nil
      @data_sources.each do |name, table|
        table.on_row_added(self.object_id)
      end
    end

    # Called when graph is dynamic and browser doesn't support web sockets
    #
    # Currently we simply send back the entire graph data as we don't want to maintain
    # unnecessary state and also assume that most experimenters use modern browsers which
    # include support for web sockets.
    #
    # def on_update(req)
      # res = @data_sources.collect do |name, table|
        # {:stream => name, :events => table.rows}
      # end
      # [res.to_json, "text/json"]
    # end

    def content()
      @wopts[:data_sources] = @data_sources.collect do |name, ds_name|
        {:stream => ds_name, :name => name}
      end
      div :id => @base_id, :class => "#{@js_class.gsub('.', '_').downcase}" do
        javascript(%{
          L.require('\##@js_class', '#@js_url', function() {
            var #{@js_var_name} = new #{@js_class}(#{@wopts.to_json});
          });
        })
      end
    end

    # def get_static_js()
      # @wopts[:data_sources] = @data_sources.collect do |name, table|
        # {:stream => "ds#{table.object_id}", :name => name}
      # end
      # "var #{@js_var_name} = new #{@js_class}(#{@wopts.to_json});"
    # end
# 
    # def get_dynamic_js()
      # return # DON'T NEED ANYMORE 
#       
#       
      # return "" unless @dynamic
# 
      # # :dynamic => true is valid option
      # updateInterval = @dynamic.is_a?(Hash) && @dynamic[:updateInterval]
# 
      # updateInterval ||= 3
# 
      # res = <<END_OF_JS
        # var ws#{@base_id};
        # //if (window.WebSocket) {
        # if (false) {  // web sockets don't work right now
          # var url = 'ws://' + window.location.host + '/_ws';
          # var ws = ws#{@base_id} = new WebSocket(url);
          # ws.onopen = function() {
            # ws.send('id:#{@widget_id}');
          # };
          # ws.onmessage = function(evt) {
            # // evt.data contains received string.
            # var msg = jQuery.parseJSON(evt.data);
            # var data = msg;
            # #{@js_var_name}.append(data);
          # };
          # ws.onclose = function() {
            # var status = "onclose";
          # };
          # ws.onerror = function(evt) {
            # var status = "onerror";
          # };
        # } else {
          # L.require(['jquery.js', '/resource/js/jquery.periodicalupdater.js'], function() {
              # $.PeriodicalUpdater('/_update?sid=#{Thread.current["sessionID"]}&wid=#{@widget_id}', {
                  # method: 'get',          // method; get or post
                  # data: '',                   // array of values to be passed to the page - e.g. {name: "John", greeting: "hello"}
                  # minTimeout: #{updateInterval * 1000},       // starting value for the timeout in milliseconds
                  # maxTimeout: #{4 * updateInterval * 1000},       // maximum length of time between requests
                  # multiplier: 2,          // if set to 2, timerInterval will double each time the response hasn't changed (up to maxTimeout)
                  # type: 'json',           // response type - text, xml, json, etc.  See $.ajax config options
                  # maxCalls: 0,            // maximum number of calls. 0 = no limit.
                  # autoStop: 0             // automatically stop requests after this many returns of the same data. 0 = disabled.
              # }, function(reply) {
                  # //#{@js_var_name}.append(data);
                  # #{@js_var_name}.update(reply);  // right now we are sending the entire graph
              # });
          # });
        # }
# END_OF_JS
    # end

    def collect_data_sources(ds_set)
      @data_sources.values.each do |ds|
        ds_set.add(ds.is_a?(Hash) ? ds : {:name => ds})
      end
      ds_set
    end



  end # AbstractDataWidget

end
