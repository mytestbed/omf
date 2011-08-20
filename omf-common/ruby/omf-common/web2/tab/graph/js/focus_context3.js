
OML['focusContext'] = function(opts) {
  this.version = "0.5";


  this.init = function(opts) {
    var opts = this.opts = opts || {};
    var h = opts.height || 300;
    var w = opts.width || 400;
    var gap = opts.gap || 20;

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

    var base_el = opts.base_el || "body";
    if (typeof(base_el) == "string") base_el = d3.select(base_el);
    var vis = base_el.append("svg:svg")
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

    fopts.base_el = fopts.base_el || vis;
    this.focus = new OML.lineChart(fopts);

    copts.base_el = copts.base_el || vis;
    copts.y = h - copts.height;
    this.context = new OML.lineChart(copts);
    var self = this;
    this.context.init_selection(function(ctxt, x_min, x_max) {
	var min = Math.round(x_min);
	var max = Math.round(x_max);

	d3.select("#x_min span").text(min);
	d3.select("#x_max span").text(max);


	if ((max - min) == 0) {
	  // clear selection
	  self.focus.clear(null);
	  return;
	}

	if ((max - min) < 3) return;
	var d = ctxt.data.map(function(d) {
	    var res = d.filter(function(r) {
		var x = r.x;
		return (x > min && x <= max);
	      });
	    return res;
	  });
	self.focus.update(d);
      });

    var data = opts.data;
    if (data) this.update(data);
  };

  this.update = function(data) {
    this.context.update(data);
  };

  this.init(opts);
}


