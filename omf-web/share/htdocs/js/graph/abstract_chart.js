
L.provide('OML.abstract_chart', ["/resource/vendor/d3/d3.js"], function () {

  if (typeof(OML) == "undefined") OML = {};
  
  if (typeof(d3.each) == 'undefined') {
    d3.each = function(array, f) {
      var i = 0,
          n = array.length,
          a = array[0],
          b;
      if (arguments.length == 1) {
          while (++i < n) if (a < (b = array[i])) a = b;
      } else {
        a = f(a);
        while (++i < n) if (a < (b = f(array[i]))) a = b;
      }
      return a;
    };
  };
  
  OML['abstract_chart'] = Backbone.Model.extend({
    
    decl_color_func: {
      // scale
      "green_yellow80_red()": d3.scale.linear()
                              .domain([0, 0.8, 1])
                              .range(["green", "yellow", "red"]),
      "green_red()":          d3.scale.linear()
                              .domain([0, 1])
                              .range(["green", "red"]),
      "red_yellow20_green()": d3.scale.linear()
                              .domain([0, 0.2, 1])
                              .range(["red", "yellow", "green"]),
      "red_green()":          d3.scale.linear()
                              .domain([0, 1])
                              .range(["red", "green"]),
      // category
      "category10()":         d3.scale.category10(),      
      "category20()":         d3.scale.category20(),
      "category20b()":         d3.scale.category20b(),
      "category20c()":         d3.scale.category20c(),
    },
    
    defaults: {
      base_el: "body",
      width: 0.8,  // <= 1.0 means set width to enclosing element
      height: 0.6,  // <= 1.0 means fraction of width
      margin: {
        left: 50,
        top:  20,
        right: 30,
        bottom: 50
      },
      offset: {
        x: 0,
        y: 0
      }      
    },
    
    
    
    //base_css_class: 'oml-chart',
    
    initialize: function(opts) {
      var o = this.opts = _.defaults(opts, this.defaults);
    
      var base_el = o.base_el;
      if (typeof(base_el) == "string") base_el = d3.select(base_el);
      this.base_el = base_el;
    
      this.init_data_source();
      this.process_schema();

      var w = o.width;
      if (w <= 1.0) {
        // check width of enclosing div (base_el)
        w = w * this.base_el[0][0].clientWidth;
        if (isNaN(w)) w = 800; 
      }
      this.w = w;
      
      var h = o.height;
      if (h <= 1.0) {
        h = h * w;
      }
      this.h = h;
      
      var m = _.defaults(opts.margin || {}, this.defaults.margin);
      var ca = this.chart_area = {
        x: m.left, 
        rx: w - m.left, 
        y: m.bottom, 
        ty: m.top, 
        w: w - m.left - m.right, 
        h: h - m.top - m.bottom
      };
  
      o.offset = _.defaults(opts.offset || {}, this.defaults.offset);
  
      var vis = this.init_svg(w, h);
      this.configure_base_layer(vis);
                 
      var self = this;
      OHUB.bind("graph.highlighted", function(evt) {
        if (evt.source == self) return;
        self.on_highlighted(evt);
      });
      OHUB.bind("graph.dehighlighted", function(evt) {
        if (evt.source == self) return;
        self.on_dehighlighted(evt);
      });
      
      //this.update(null);
      this.redraw();         
    },
    
    update: function(data) {
      if (data == null) {
        if ((data = this.data_source.events) == null) {
          throw "Missing events array in data source"
        }
      }
      this.data = data;
      this.redraw();
    },
    

    // Find the appropriate data source and bind to it
    //
    init_data_source: function() {
      var o = this.opts;
      var sources = o.data_sources;
      var self = this;
      
      if (! (sources instanceof Array)) {
        throw "Expected an array"
      }
      if (sources.length != 1) {
        throw "Can only process a SINGLE source"
      }
      var ds = this.data_source = OML.data_sources[sources[0].stream];
      if (o.dynamic == true) {
        ds.on_changed(function(evt) {
          self.redraw();
        });
      }

    },
    
    init_svg: function(w, h) {
      var opts = this.opts;
      
      var vis = opts.svg = this.svg_base = this.base_el.append("svg:svg")
        .attr("width", w)
        .attr("height", h)
        .attr('class', this.base_css_class);
      var offset = opts.offset;
      if (offset.x) {
        // the next two lines do the same, but only one works 
        // in the specific context
        vis.attr("x", offset.x);
        vis.style("margin-left", offset.x + "px"); 
      }
      if (offset.y) {
        vis.attr("y", offset.y);
        vis.style("margin-top", offset.y + "px"); 
      }
      return vis;
    },

    // Split tuple array into array of tuple arrays grouped by 
    // the tuple element at +index+.
    //
    group_by: function(in_data, index_f) {
      var data = [];
      var groups = {};
      
      _.map(in_data, function(d) {
        var key = index_f(d);
        var a = groups[key];
        if (!a) {
          a = groups[key] = [];
          data.push(a);
        }
        a.push(d);
      });
      // Sort by 'group_by' index to keep the same order and with it same color assignment.
      var data = _.sortBy(data, function(a) {
        return index_f(a[0])
      }); 
      return data;
    },

    init_selection: function(handler) {
      var self = this;
      this.ic = {
           handler: handler,
      };
  
      var ig = this.base_layer.append("svg:g")
        .attr("pointer-events", "all")
        .on("mousedown", mousedown);
  
      var ca = this.chart_area;
      var frame = ig.append("svg:rect")
        .attr("class", "graph-area")
        .attr("x", ca.x)
        .attr("y", -1 * (ca.y + ca.h))
        .attr("width", ca.w)
        .attr("height", ca.h)
        .attr("fill", "none")
        .attr("stroke", "none")
        ;
  
      function mousedown() {
        var ic = self.ic;
        if (!ic.rect) {
          ic.rect = ig.append("svg:rect")
            .attr("class", "select-rect")
            .attr("fill", "#999")
            .attr("fill-opacity", .5)
            .attr("pointer-events", "all")
            .on("mousedown", mousedown_box)
            ;
        }
        ic.x0 = d3.svg.mouse(ic.rect.node());
        ic.is_dragging = true;
        ic.has_moved = false;
        ic.move_event_consumed = false;
        d3.event.preventDefault();
      }
  
      function mousedown_box() {
        var ic = self.ic;
        mousedown();
        if (ic.minx) {
          ic.offsetx = ic.x0[0] - ic.minx;
        }
      }
  
      function mousemove(x, d, i) {
        var ic = self.ic;
        var ca = self.chart_area;
  
        if (!ic.rect) return;
        if (!ic.is_dragging) return;
        ic.has_moved = true;
  
        var x1 = d3.svg.mouse(ic.rect.node());
        var minx;
        if (ic.offsetx) {
          minx = Math.max(ca.x, x1[0] - ic.offsetx);
          minx = ic.minx = Math.min(minx, ca.x + ca.w - ic.width); 
        } else {
          minx = ic.minx = Math.max(ca.x, Math.min(ic.x0[0], x1[0]));
          var maxx = Math.min(ca.x + ca.w, Math.max(ic.x0[0], x1[0]));
          ic.width = maxx - minx;
        }
        self.update_selection({screen_minx: minx});
      }
  
      function mouseup() {
        var ic = self.ic;
        if (!ic.rect) return;
        ic.offsetx = null;
        ic.is_dragging = false;
        if (!ic.has_moved) {
          // click only. Remove selction
          ic.width = 0;
          ic.rect.attr("width", 0);
          if (ic.handler) ic.handler(this, 0, 0);
        }
      }
  
      d3.select(window)
          .on("mousemove", mousemove)
          .on("mouseup", mouseup);
    },
  
    update_selection: function(selection) {
      if (!this.ic) return;
  
      var ic = this.ic;
      var ca = this.chart_area;
  
      var sminx = selection.screen_minx;
      if (sminx) {
        ic.rect
          .attr("x", sminx)
          .attr("y", -1 * (ca.y + ca.h)) //self.y(self.y_max))
          .attr("width", ic.width)
          .attr("height",  ca.h); //self.y(self.y_max) - self.y(0));
        ic.sminx = sminx;
      }
      sminx = ic.sminx;
      var h = ic.handler;
      if (sminx && ic.handler) {
        var imin = this.x.invert(sminx);
        var imax = this.x.invert(sminx + ic.width);
        ic.handler(this, imin, imax);
      }
    },
    
    /*************
     * Deal with schema and turn +mapping+ instructions into actionable functions.
     */
    
    process_schema: function() {
      // var self = this;
      // var o = this.opts;
      // var schema = this.schema = {};
      // _.map(this.data_source.schema, function(s, i) {
          // s['index'] = i;
          // schema[s.name] = s;
      // });
//       
      // var m = this.mapping = {};
      // var om = o.mapping || {};      
      // _.map(this.decl_properties, function(a) {
        // var pname = a[0]; var type = a[1]; var def = a[2];
        // var descr = om[pname];
        // m[pname] = self.create_mapping(pname, descr, null, type, def)
      // });
      // var i = 0;
      
      this.schema = this.process_single_schema(this.data_source);
      this.mapping = this.process_single_mapping(null, this.opts.mapping, this.decl_properties);
      
    },
    
    process_single_schema: function(data_source) {
      var self = this;
      var o = this.opts;
      var schema = {};
      _.map(data_source.schema, function(s, i) {
          s['index'] = i;
          schema[s.name] = s;
      });
      return schema;
    },
   
    process_single_mapping: function(source_name, mapping_decl, properties_decl) {
      var self = this;
      var m = {};
      var om = mapping_decl || {};      
      _.map(properties_decl, function(a) {
        var pname = a[0]; var type = a[1]; var def = a[2];
        var descr = om[pname];
        m[pname] = self.create_mapping(pname, descr, source_name, type, def)
      });
      return m;
    },

   /*
    * Return schema for +stream+.
    */
   schema_for_stream: function(stream) {
     if (stream != undefined) {
       throw "Can't provide named stream '" + stream + "'.";
     }
     return this.schema;
   },  
   
   /*
    * Return data_source named 'name'.
    */
   data_source_for_stream: function(name) {
     if (name != undefined) {
       throw "Can't provide named stream '" + name + "'.";
     }
     return this.data_source;
   },  

    
    
   create_mapping: function(mname, descr, stream, type, def) {
     var self = this;
     if (descr == undefined && typeof(def) == 'object') {
       descr = def
     }
     if (descr == undefined || typeof(descr) != 'object' ) {
       if (type == 'index') {
         return this.create_mapping(mname, def, stream, type, null);
       } else if (type == 'key') {
         return this.create_mapping(mname, {property: descr}, stream, type, def);
       } else {
         var value = (descr == undefined) ? def : descr;
         if (type == 'color' && /\(\)$/.test(value)) {
           //var t = /\(\)$/.test(value); // check if value ends with () indicating color function
           value = this.decl_color_func[value];
         }
         return value;
       }
     }
     if (descr.stream != undefined) {
       stream = descr.stream;  // override stream
     }
     var schema = this.schema_for_stream(stream);
     if (schema == undefined) {
       throw "Can't find schema for stream '" + stream + "'.";
     }
     
     if (type == 'index') {
       var key = descr.key;
       if (key == undefined || stream == undefined) {
         throw "Missing 'key' or 'stream' in mapping declaration for '" + mname + "'.";
       }
       var col_schema = schema[key];
       if (col_schema == undefined) {
         throw "Unknown stream element '" + key + "'.";
       }
       var vindex = col_schema.index;
       
       var jstream_name = descr.join_stream;
       if (jstream_name == undefined) {
         throw "Missing join stream declaration in '" + mname + "'.";
       }
       var jschema = this.schema_for_stream(jstream_name);
       if (jschema == undefined) {
         throw "Can't find schema for stream '" + jstream_name + "'.";
       }
       var jstream = this.data_source_for_stream(jstream_name);

       var jkey = descr.join_key;
       if (jkey == undefined) jkey = 'id';
       var jcol_schema = jschema[jkey];       
       if (jcol_schema == undefined) {
         throw "Unknown stream element '" + jkey + "' in '" + jstream + "'.";
       }
       var jindex = jcol_schema.index;
       jstream.create_index(jindex);
       
       return function(d) {
         var join = d[vindex];
         var t = jstream.get_indexed_row(jindex, join); //self.get_indexed_table(jstream, jindex);
         //var r = t[join];
         return t;
       }
     } else {
       var pname = descr.property;
       if (pname == undefined) {
         throw "Missing 'property' declaration for mapping '" + mname + "'.";
       }
       var col_schema = schema[pname];
       if (col_schema == undefined) {
         if (descr.optional == true) {
           return undefined;  // don't need to be mapped
         }
         throw "Unknown property '" + pname + "'.";
       }
       var index = col_schema.index;
       switch (type) {
       case 'int': 
       case 'float':        
         var scale = descr.scale;
         var min_value = descr.min;
         var max_value = descr.max;
         return function(d) {
           var v = d[index];
           if (scale != undefined) v = v * scale; 
           if (min_value != undefined && v < min_value) v = min_value; 
           if (max_value != undefined && v > max_value) v = max_value; 
           return v;
         };
       case 'color': 
         var color_fname = descr.color;
         if (color_fname == undefined) {
           throw "Missing color function for '" + mname + "'.";
         } 
         var color_f = self.decl_color_func[color_fname];
         if (color_f == undefined) {
           throw "Unknown color function '" + color_fname + "'.";
         } 
         var scale = descr.scale;
         var min_value = descr.min;
         return function(d) {
           var v = d[index];
           if (scale != undefined) v = v * scale; 
           if (min_value != undefined && v < min_value) v = min_value; 
           var color = color_f(v);
           return color;
         };
       case 'key' :
         return function(d) {
           return d[index];
         }
       default:    
         throw "Unknown mapping type '" + type + "'";
       }
     }
     var i = 0;
   }
    

    
    
  });
})