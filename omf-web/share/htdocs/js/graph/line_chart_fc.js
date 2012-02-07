L.provide('OML.line_chart_fc', ["d3/d3", "graph/line_chart", '#OML.line_chart'], function () {

  OML['line_chart_fc'] = function(opts) {
    this.version = "0.5";
  
  
    this.init = function(opts) {
      var opts = this.opts = opts || {};
      var h = opts.height || 300;
      var w = opts.width || 400;
      var gap = opts.gap || 20;
      var vis = this.init_svg(w, h);
  
      var fopts = opts.focus || {};
      var copts = opts.context || {};
      
      // calculate height of two graphs.
      var fh = fopts.height;
      var ch = copts.height;
      if (fh && !ch) ch = 1.0 - fh;
      if (!fh && ch) fh = 1.0 - ch;
      if (!fh && !ch) { ch = 0.3; fh = 1.0 - ch};
      fopts.height = (h - gap) * fh;
      copts.height = (h - gap) * ch;
  
      fopts.width = copts.width = w;
      fopts.schema = opts.schema;
      fopts.mapping = fopts.mapping || opts.mapping;
      fopts.svg = fopts.base_el = vis;
      this.focus = new OML.line_chart(fopts);
  
      copts.svg = copts.base_el = vis;
      copts.schema = opts.schema;
      copts.mapping = copts.mapping || opts.mapping;
      copts.y = h - copts.height;
      this.context = new OML.line_chart(copts);
      var self = this;
      this.context.init_selection(function(ctxt, x_min, x_max) {
      	var min = Math.round(x_min);
      	var max = Math.round(x_max);
      
      	// d3.select("#x_min span").text(min);
      	// d3.select("#x_max span").text(max);
      
      	if ((max - min) == 0) {
      	  // clear selection
      	  self.focus.clear(null);
      	  return;
      	}
      	if ((max - min) < 3) return;
      	
      	var d = ctxt.filter_x(min, max)
      	self.focus.update([{name: 'default', events: d}]);
      });
  
      var data = opts.data;
      if (data) this.update(data);
    };
  
    this.append = function(data) {
      this.context.append(data);
    };

    this.update = function(data) {
      this.context.update(data);
    };
    
    this.init_svg = function(w, h) {
      var opts = this.opts;

      if (opts.svg) return opts.svg;
      
      var base_el = opts.base_el || "body";
      if (typeof(base_el) == "string") base_el = d3.select(base_el);
      var vis = opts.svg = base_el.append("svg:svg")
        .attr("width", w)
        .attr("height", h);
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
    }
  
    this.init(opts);
  }
})

