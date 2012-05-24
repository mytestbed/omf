
L.provide('OML.abstract_widget', [], function () {

  if (typeof(OML) == "undefined") OML = {};
  
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
      
      var m = _.defaults(opts.margin || {}, this.defaults.margin);
      this.widget_area = {
        x: m.left, 
        rx: w - m.left, 
        y: m.bottom, 
        ty: m.top, 
        w: w - m.left - m.right, 
        h: h - m.top - m.bottom
      };
  
      o.offset = _.defaults(opts.offset || {}, this.defaults.offset);
  
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