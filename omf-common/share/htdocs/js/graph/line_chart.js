if (typeof(OML) == "undefined") {
  OML = {};
}

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

OML['line_chart'] = function(opts) { 
  this.opts = opts || {};
  this.data = null;
  
  this.init = function() {
    var o = this.opts;

    var w = o['width'] || 600;
    var h = o['height'] || 400;

    var m = o['margin'] || {};
    var ml = m['left'] || 20;
    var mt = m['top'] || 0;
    var mr = m['right'] || 0;
    var mb = m['bottom'] || 20;
    var ca = this.chart_area = {x: ml, y: mb, w: w - ml - mr, h: h - mt - mb};

    var offset = o['offset'] || [0, 0];

    this.color = o['color'] || d3.scale.category10();


    var base_el = o.base_el || "body";
    if (typeof(base_el) == "string") {
      base_el = d3.select(base_el);
    }
    base_el.attr("style", "width:" + w + "px;height:" + h + "px");    

    
    var vis = base_el.append("svg:svg")
      .attr("class", "oml-lineGraph")
      .attr("width", w)
      .attr("height", h);
    if (o.x) {
      // the next two lines do the same, but only one works 
      // in the specific context
      vis.attr("x", o.x);
      vis.style("margin-left", o.x + "px"); 
    }
    if (o.y) {
      vis.attr("y", o.y);
      vis.style("margin-top", o.y + "px"); 
    }

    var g =  this.base_layer = vis.append("svg:g")
               .attr("transform", "translate(0, " + h + ")");

    this.graph_layer = g.append("svg:g");
    g.append("svg:line")
      .attr("x1", ca.x)
      .attr("y1", -1 * ca.y)
      .attr("x2", ca.x + ca.w)
      .attr("y2", -1 * ca.y);

    g.append("svg:line")
      .attr("x1", ca.x)
      .attr("y1", -1 * ca.y)
      .attr("x2", ca.x)
      .attr("y2", -1 * (ca.y + ca.h));

    var data = o.data;
    if (data) this.update(data);
  };

  this.update = function(data) {
    var self = this;
    this.data = data;
    var o = this.opts;
    var ca = this.chart_area;

    //    var x_max = this.x_max = d3.max(data, function(d) {return d3.max(d, function(d) {return d.x})});
    var x_max = this.x_max = d3.max(data, function(s) {
      var d = s.data; 
      return d[d.length - 1][0];});
    var x_max_cnt = d3.max(data, function(s) {return s.data.length});
    var x_min = this.x_min = d3.min(data, function(s) {var d = s.data; return d[0][0];});
    var x = this.x = d3.scale.linear().domain([x_min, x_max]).range([ca.x, ca.x + ca.w]);

    if (x_max_cnt > ca.w) {
      // To much data, downsample
      var data2 = [];
      data.map(function(l) {
          var xcurr = -999999;
          var l2 = [];
          l.map(function(d) {
              var x = Math.round(self.x(d.x));
              if (x > xcurr) {
                l2.push(d);
                xcurr = x + 1; // add a 'spare' pixel between consecutive points
              }
            });
          data2.push(l2);
        });
      data = data2;
    }


    //    var x_min = this.x_min = d3.min(data, function(d) {return d3.min(d, function(d) {return d.x})});
    var y_max = this.y_max = o.ymax != undefined ? o.ymax : d3.max(data, function(s) {return d3.max(s.data, function(d) {return d[1]})});
    var y_min = this.y_min = o.ymin != undefined ? o.ymin : d3.min(data, function(s) {return d3.min(s.data, function(d) {return d[1]})});
    var y = this.y = d3.scale.linear().domain([y_min, y_max]).range([ca.y, ca.y + ca.h]);


    var line = d3.svg.line()
      .x(function(d) { return x(d[0]) })
      .y(function(d) { return -1 * y(d[1]); })
      ;

    var self = this;
    var lines = this.graph_layer.selectAll(".chart")
                  .data(data, function(d, i) { return i; })
                  .attr("d", function(d) { return line(d.data); });
    lines.enter()
      .append("svg:path")
        .attr("stroke-width", 2)
        .attr("d", function(d) {
            var l = line(d.data);
            return l;
          })

        .attr("class", "chart")
        .attr("stroke", function(d, i) { 
            return self.color(i); 
          })
        ;
    lines.exit().remove();

    this.update_ticks();
    this.update_selection({});
  };

  this.clear = function(data) {
    this.data = null;
    var lines = this.graph_layer.selectAll(".chart")
                  .data([])
                  .exit().remove();
  };

  this.update_ticks = function() {
    var y = this.y;
    var x = this.x;
    var g = this.base_layer;
    var ca = this.chart_area;

    var tick_length = 7;
    var label_spacing = tick_length + 2;

    var xa_opts = this.opts['xaxis'] || {};
    var ya_opts = this.opts['yaxis'] || {};

    var xTicksA = x.ticks(xa_opts['ticks'] || 5);
    if (xa_opts['show_labels'] != false) {
      var xFormat = xa_opts['label'] || function(d) {return d};
      var xLabel = g.selectAll(".xLabel")
          .data(xTicksA)
          .text(xFormat)
          .attr("x", function(d) { return x(d) });
      xLabel.enter().append("svg:text")
          .attr("class", "xLabel")
          .text(xFormat)
          .attr("x", function(d) { return x(d) })
          .attr("y", -1 * (ca.y - label_spacing))
          .attr("text-anchor", "middle")
          .attr("dominant-baseline", "text-before-edge");
      xLabel.exit().remove();

      var xTicks = g.selectAll(".xTicks")
        .data(xTicksA)
        .attr("x1", function(d) { return x(d); })
        .attr("x2", function(d) { return x(d); })
      xTicks.enter().append("svg:line")
        .attr("class", "xTicks")
        .attr("x1", function(d) { return x(d); })
        .attr("y1", -1 * ca.y)
        .attr("x2", function(d) { return x(d); })
        .attr("y2", -1 * (ca.y - tick_length));
      xTicks.exit().remove();
    };

    if (xa_opts['show_grids'] != false) {
      var xGrids = g.selectAll(".xGrids")
        .data(xTicksA)
        .attr("x1", function(d) { return x(d); })
        .attr("x2", function(d) { return x(d); })
      xGrids.enter().append("svg:line")
        .attr("class", "xGrids grids")
        .attr("x1", function(d) { return x(d); })
        .attr("y1", -1 * ca.y)
        .attr("x2", function(d) { return x(d); })
        .attr("y2", -1 * (ca.h + ca.y));
      xGrids.exit().remove();
    };

    var yTicksA = y.ticks(ya_opts['ticks'] || 4);
    if (ya_opts['show_labels'] != false) {
      var yFormat = ya_opts['label'] || function(d) {return d};

      var yLabel = g.selectAll(".yLabel")
          .data(yTicksA)
          .text(yFormat)
          .attr("y", function(d) { return -1 * y(d) })
      yLabel.enter().append("svg:text")
          .attr("class", "yLabel")
          .text(yFormat)
          .attr("x", ca.x - label_spacing)
          .attr("y", function(d) { return -1 * y(d) })
          .attr("text-anchor", "end")
          .attr("dy", 4);
      yLabel.exit().remove();

      var yTicks = g.selectAll(".yTicks")
        .data(yTicksA)
        .attr("y1", function(d) { return -1 * y(d); })
        .attr("y2", function(d) { return -1 * y(d); })
      yTicks.enter().append("svg:line")
        .attr("class", "yTicks")
        .attr("y1", function(d) { return -1 * y(d); })
        .attr("x1", ca.x - tick_length)
        .attr("y2", function(d) { return -1 * y(d); })
        .attr("x2", ca.x);
      yTicks.exit().remove();
    }

    if (ya_opts['show_grids'] != false) {
      var yGrids = g.selectAll(".yGrids")
        .data(yTicksA)
        .attr("y1", function(d) { return -1 * y(d); })
        .attr("y2", function(d) { return -1 * y(d); })
      yGrids.enter().append("svg:line")
        .attr("class", "yGrids grids")
        .attr("stroke", "grey")
        .attr("y1", function(d) { return -1 * y(d); })
        .attr("x1", ca.x + ca.w)
        .attr("y2", function(d) { return -1 * y(d); })
        .attr("x2", ca.x);
      yGrids.exit().remove();
    }
  };


  this.init_selection = function(handler) {
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
  };

  this.update_selection = function(selection) {
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
  };

  this.init(opts);
};

/*
  Local Variables:
  mode: Javascript
  tab-width: 2
  indent-tabs-mode: nil
  End:
*/