
L.provide('OML.abstract_chart', ["d3/d3"], function () {

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
    
    base_css_class: 'oml-chart',
    
    initialize: function(opts) {
      this.opts = opts;
      var o = this.opts;
  
      var w = this.w = o['width'] || 700;
      var h = this.h = o['height'] || 400;
  
      var m = o['margin'] || {};
      var ml = m['left'] || 30;
      var mt = m['top'] || 20;
      var mr = m['right'] || 20;
      var mb = m['bottom'] || 20;
      var ca = this.chart_area = {x: ml, y: mb, w: w - ml - mr, h: h - mt - mb};
  
      var offset = o['offset'] || [0, 0];
  
      var vis = this.init_svg(w, h);
      this.configure_base_layer(vis);
                 
      this.process_schema();
      
      var self = this;
      OHUB.bind("graph.highlighted", function(evt) {
        if (evt.source == self) return;
        self.on_highlighted(evt);
      });
      OHUB.bind("graph.dehighlighted", function(evt) {
        if (evt.source == self) return;
        self.on_dehighlighted(evt);
      });
      
      var data = o.data;
      if (data) this.update(data);
                 
    },
    
    append: function(a_data) {
      // TODO: THIS DOESN'T WORK
      //var data = this.data;
      this.redraw();   
    },

    update: function(sources) {
      if (! (sources instanceof Array)) {
        throw "Expected an array"
      }
      if (sources.length != 1) {
        throw "Can only process a SINGLE source"
      }
      if ((this.data = sources[0].events) == null) {
        throw "Missing events array in data source"
      }
      this.redraw();
    },
    
    init_svg: function(w, h) {
      var opts = this.opts;
      
      var base_el = opts.base_el || "body";
      if (typeof(base_el) == "string") base_el = d3.select(base_el);
      var vis = opts.svg = this.svg_base = base_el.append("svg:svg")
        .attr("width", w)
        .attr("height", h)
        .attr('class', this.base_css_class);
      if (opts.x) {
        // the next two lines do the same, but only one works 
        // in the specific context
        vis.attr("x", opts.x);
        vis.style("margin-left", opts.x + "px"); 
      }
      if (opts.y) {
        vis.attr("y", opts.y);
        vis.style("margin-top", opts.y + "px"); 
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
      var self = this;
      var o = this.opts;
      var schema = this.schema = {};
      _.map(o.schema, function(s, i) {
          s['index'] = i;
          schema[s.name] = s;
      });
      
      var m = this.mapping = {};
      var om = o.mapping || {};      
      _.map(this.decl_properties, function(a) {
        var pname = a[0]; var type = a[1]; var def = a[2];
        var descr = om[pname];
        m[pname] = self.create_mapping(pname, descr, null, type, def)
      });
      var i = 0;
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
    
    
   create_mapping: function(mname, descr, stream, type, def) {
     var self = this;
     if (descr == undefined && typeof(def) == 'object') {
       descr = def
     }
     if (descr == undefined || typeof(descr) != 'object' ) {
       if (type == 'index') {
         return this.create_mapping(mname, def, stream, type, null);
       } else {
         var value = (descr == undefined) ? def : descr;
         return value;
         return function(d) { 
           return value; 
         }
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
       
       var jstream = descr.join_stream;
       if (jstream == undefined) {
         throw "Missing join stream declaration in '" + mname + "'.";
       }
       var jschema = this.schema_for_stream(jstream);
       if (jschema == undefined) {
         throw "Can't find schema for stream '" + jstream + "'.";
       }

       var jkey = descr.join_key;
       if (jkey == undefined) jkey = 'id';
       var jcol_schema = jschema[jkey];       
       if (jcol_schema == undefined) {
         throw "Unknown stream element '" + jkey + "' in '" + jstream + "'.";
       }
       var jindex = jcol_schema.index;
       
       return function(d) {
         var join = d[vindex];
         var t = self.get_indexed_table(jstream, jindex);
         var r = t[join];
         return r;
       }
     } else {
       var pname = descr.property;
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