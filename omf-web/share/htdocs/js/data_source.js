
OML['data_source'] = function(name, updateURL, updateInterval, schema, events) {
  this.version = "0.1";


  this.init = function() {
    this.event_name = "data_source." + this.name + ".changed";
    this.indexes = [];
    this.is_dynamic = false;
  };
  
  this.name = name;
  this.update_url = updateURL;
  this.update_interval = updateInterval;
  this.schema = schema;
  this.events = events; // array of events
  this.init();
  
  this.create_index = function(index) {
    var idx = this.indexes[index];
    if (idx) return;
    
    this._create_index(index);
  };
    
  this._create_index = function(index) {
    idx = this.indexes[index] = {};
    // index ignores rows with identical index
    _.map(this.events, function(r) {
      idx[r[index]] = r;
    });
  };
  
  this.get_indexed_row = function(index, key) {
    var idx = this.indexes[index];
    if (idx == undefined) {
      throw "Need to create index first";
    }
    return idx[key];
  }
  
  this.update_indexes = function() {
    var self = this;
    _.each(this.indexes, function(value, key) {
      var i = 0;
      self._create_index(key);
    });
    
  }
  
  this.on_changed = function(update_f) {
            
    OHUB.bind(this.event_name, update_f);
    
    if (this.is_dynamic) return;

    // First time around. Need to configure update machinery 
    //    
    var self = this;
    //if (window.WebSocket) {
    if (false) {  // web sockets don't work right now
      var url = 'ws://' + window.location.host + '/_ws';
      var ws = this.ws = new WebSocket(url);
      ws.onopen = function() {
        ws.send('id:' + this.name);
      };
      ws.onmessage = function(evt) {
        // evt.data contains received string.
        var msg = jQuery.parseJSON(evt.data);
        var data = msg;
        this.events.append(data);
      };
      ws.onclose = function() {
        var status = "onclose";
      };
      ws.onerror = function(evt) {
        var status = "onerror";
      };
    } else {
      L.require(['/resource/vendor/jquery/jquery.js', '/resource/vendor/jquery/jquery.periodicalupdater.js'], function() {
        var update_interval = self.update_interval * 1000;
        if (update_interval < 1000) update_interval = 3000;
        var opts = {
              method: 'get',          // method; get or post
              data: '',                   // array of values to be passed to the page - e.g. {name: "John", greeting: "hello"}
              minTimeout: update_interval,       // starting value for the timeout in milliseconds
              maxTimeout: 4 * update_interval,       // maximum length of time between requests
              multiplier: 2,          // if set to 2, timerInterval will double each time the response hasn't changed (up to maxTimeout)
              type: 'json',           // response type - text, xml, json, etc.  See $.ajax config options
              maxCalls: 0,            // maximum number of calls. 0 = no limit.
              autoStop: 0             // automatically stop requests after this many returns of the same data. 0 = disabled.
        };
        $.PeriodicalUpdater(self.update_url, opts, function(reply) {
          self.events = reply.events;
          self.update_indexes();
          reply.data_source = self;
          OHUB.trigger(self.event_name, reply);
        });
      });
    }    
    
    this.is_dynamic = true;
  }
}

