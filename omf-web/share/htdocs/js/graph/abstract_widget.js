
L.provide('OML.abstract_widget', ["/resource/vendor/d3/d3.js"], function () {

  if (typeof(OML) == "undefined") OML = {};

  if (typeof(d3.each) == 'undefined') {
    d3.each = function(array, f) {
      var i = 0, n = array.length, a = array[0], b;
      if (arguments.length == 1) {
          while (++i < n) if (a < (b = array[i])) a = b;
      } else {
        a = f(a);
        while (++i < n) if (a < (b = f(array[i]))) a = b;
      }
      return a;
    };
  };
  
  
  OML['abstract_widget'] = Backbone.Model.extend({
    
    defaults: function() {
      return {
        base_el: "body",
        width: 1.0,  // <= 1.0 means set width to enclosing element
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
        },
      }     
    },
    
    //base_css_class: 'oml-chart',
    
    initialize: function(opts) {
      var o = this.opts = this.deep_defaults(opts, this.defaults());
    
      var base_el = o.base_el;
      if (typeof(base_el) == "string") base_el = d3.select(base_el);
      this.base_el = base_el;
    
      // this.init_data_source();
      // this.process_schema();
// 
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
      
      //var m = _.defaults(opts.margin || {}, this.defaults.margin);
      var m = o.margin;
      this.widget_area = {
        x: m.left, 
        rx: w - m.left, 
        y: m.bottom, 
        ty: m.top, 
        w: w - m.left - m.right, 
        h: h - m.top - m.bottom
      };
  
      //o.offset = _.defaults(opts.offset || {}, this.defaults.offset);

      this.init_data_source();
      this.process_schema();
  
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
      this.data_source = this.init_single_data_source(sources[0]);
    },
    
    
    // Find the appropriate data source and bind to it
    //
    init_single_data_source: function(ds_descr) {
      var ds = OML.data_sources.lookup(ds_descr.stream);
      var self = this;
      if (ds.is_dynamic()) {
        ds.on_changed(function(evt) {
          self.update();
        });
      }
      return ds;
    },
    
    
    process_schema: function() {
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
    },

    
    // Fill in a given object (and any objects it contains) with default properties.
    // ... borrowed from unerscore.js
    //
    deep_defaults: function(source, defaults) {
      for (var prop in defaults) {
        if (source[prop] == null) {
          source[prop] = defaults[prop];
        } else if((typeof(source[prop]) == 'object') && defaults[prop]) {
          this.deep_defaults(source[prop], defaults[prop])
        }
      }
      return source;
    },
    
    
  });
})