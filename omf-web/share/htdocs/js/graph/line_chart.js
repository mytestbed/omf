L.provide('OML.line_chart', ["d3/d3"], function () {

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
  
  OML['line_chart'] = function(opts) { 
    this.opts = opts || {};
    this.data = null;
    
    this.init = function() {
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
  
      this.color = o['color'] || d3.scale.category10();
  
  
      var vis = this.init_svg(w, h);
      
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
  
      this.process_schema();
      var data = this.data = o.data;
      if (data) this.redraw();
      
    };
    
    this.append = function(a_data) {
      // TODO: THIS DOESN'T WORK
      //var data = this.data;
      this.redraw();   
    };

    this.update = function(data) {
      this.data = data;
      this.redraw();
    };

  
    this.redraw = function() {
      var self = this;
      var data = this.data;
      if (data.length == 0) return;
      
      var o = this.opts;
      var ca = this.chart_area;
  
      /* 'data' should be an an array (each line) of arryas (each tuple)
       * The following code assumes that the tuples are sorted in ascending 
       * value associated with the x-axis. 
       */
      var x_index = this.mapping.x_axis;
      var y_index = this.mapping.y_axis;
      var group_by = this.mapping.group_by;
      if (group_by) {
        data = this.group_by(data, group_by);
      } else {
        data = [data];
      };
      
      var x_max = this.x_max = d3.max(data, function(d) {
        return d[d.length - 1][x_index];});
      var x_max_cnt = d3.max(data, function(d) {return d.length});
      var x_min = this.x_min = d3.min(data, function(d) {return d[0][x_index];});
      var x = this.x = d3.scale.linear().domain([x_min, x_max]).range([ca.x, ca.x + ca.w]);
  
      if (x_max_cnt > ca.w) {
        // To much data, downsample
        var data2 = [];
        data.map(function(l) {
            var xcurr = -999999;
            var l2 = [];
            l.map(function(t) {
                var x = Math.round(self.x(t[x_index]));
                if (x > xcurr) {
                  l2.push(t);
                  //xcurr = x + 1; // add a 'spare' pixel between consecutive points
                  xcurr = x;
                }
              });
            data2.push(l2);
          });
        data = data2;
      }
  
  
      //    var x_min = this.x_min = d3.min(data, function(d) {return d3.min(d, function(d) {return d.x})});
      var y_max = this.y_max = o.ymax != undefined ? o.ymax : d3.max(data, function(s) {return d3.max(s, function(t) {return t[y_index]})});
      var y_min = this.y_min = o.ymin != undefined ? o.ymin : d3.min(data, function(s) {return d3.min(s, function(t) {return t[y_index]})});
      var y = this.y = d3.scale.linear().domain([y_min, y_max]).range([ca.y, ca.y + ca.h]);
  
  
      var line = d3.svg.line()
        .x(function(t) { return x(t[x_index]) })
        .y(function(t) { return -1 * y(t[y_index]); })
        ;
  
      var self = this;
      var lines = this.graph_layer.selectAll(".chart")
                    .data(data, function(d, i) { return i; })
                    .attr("d", function(d) { return line(d); });
      lines.enter()
        .append("svg:path")
          .attr("stroke-width", 2)
          .attr("d", function(d) {
              var l = line(d);
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
    
    // Split tuple array into array of tuple arrays grouped by 
    // the tuple element at +index+.
    //
    this.group_by = function(in_data, index) {
      var data = [];
      var groups = {};
      in_data.map(function(t) {
        key = t[index];
        a = groups[key];
        if (!a) {
          a = groups[key] = [];
          data.push(a);
        }
        a.push(t);
      });
      return data;
    }
  
    this.clear = function(data) {
      this.data = null;
      var lines = this.graph_layer.selectAll(".chart")
                    .data([])
                    .exit().remove();
    };
    
    // Return a subset of the associated data set where the value mapped
    // to the x-axis is within the <+min+, +max> range.
    //
    this.filter_x = function(min, max) {
      var xi = this.mapping.x_axis;
      return this.data.filter(function(t) {
        var x = t[xi];
        return (x > min && x <= max);
      })
    }
  
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
  
      var yTicksCnt = ya_opts['ticks'] ? ya_opts['ticks'] : (this.h / 30);
      var yTicksA = y.ticks(yTicksCnt);
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
    
    this.process_schema = function() {
      var o = this.opts;
      var i = 0;
      var mapping = o.mapping || {};
      var m = this.mapping = {};
      var schema = o.schema;
      if (schema) {
        schema.map(function(c) {
          ['x_axis', 'y_axis', 'group_by'].map(function(k) {
            if (c.name == o.mapping[k]) {
              m[k] = i
            }
          });
          i += 1;
        })
      } else {
        m.x_axis = 0;
        m.y_axis = 1;
      }
    };
    
    this.init_svg = function(w, h) {
      var opts = this.opts;

      //if (opts.svg) return opts.svg;
      
      var base_el = opts.base_el || "body";
      if (typeof(base_el) == "string") base_el = d3.select(base_el);
      var vis = opts.svg = base_el.append("svg:svg")
        .attr("width", w)
        .attr("height", h)
        .attr('class', 'oml-line-chart');
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
  };
})

// var AAA = function(x) {
  // this.x = x;
// }
// 
// AAA.prototype = {
  // aaa: function() {
    // var x = arguments;
    // return this.x;
  // },
// 
  // bbb: function() {
    // return this.x;
  // }
// }
// 
// var AAA_1 = new AAA(5);
// var AAA_2 = AAA_1.aaa(7, 'a');
// 
// var BBB = function(x) {
  // this.x = x;
// }
// 
// BBB.prototype = {
//   
  // bbb: function() {
    // return 2 * this.x;
  // }
// }
// 
// BBB.prototype.prototype = AAA;
// 
// 
// var BBB_1 = new BBB(5);
// var BBB_2 = BBB_1.aaa(7, 'a');
// var BBB_3 = BBB_1.bbb();
/*
  Local Variables:
  mode: Javascript
  tab-width: 2
  indent-tabs-mode: nil
  End:
*/