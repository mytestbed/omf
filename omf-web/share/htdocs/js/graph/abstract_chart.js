
L.provide('OML.abstract_chart', ["graph/abstract_widget", "#OML.abstract_widget", "/resource/vendor/d3/d3.js"], function () {

  
  OML.abstract_chart = OML.abstract_widget.extend({
    
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
        
    //base_css_class: 'oml-chart',
    
    initialize: function(opts) {
      OML.abstract_chart.__super__.initialize.call(this, opts);
      
  
      var vis = this.init_svg(this.w, this.h);
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
      this.update();         
    },
    

    // Find the appropriate data source and bind to it
    //
    // init_data_source: function() {
      // var o = this.opts;
      // var sources = o.data_sources;
      // var self = this;
//       
      // if (! (sources instanceof Array)) {
        // throw "Expected an array"
      // }
      // if (sources.length != 1) {
        // throw "Can only process a SINGLE source"
      // }
      // var ds = this.data_source = OML.data_sources[sources[0].stream];
      // if (o.dynamic == true) {
        // ds.on_changed(function(evt) {
          // self.update();
        // });
      // }
// 
    // },
    
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
    
    
    on_highlighted: function(evt) {},
    on_dehighlighted: function(evt) {},
    
    
    // Return an array with the 'min' and 'max' value returned by running 'f' over 'data'
    // However, any 'min' and 'max' values in 'opts' take precedence.
    //
    extent: function(data, f, opts) {
      var o = opts || {};
      var max = o.max != undefined ? o.max : d3.max(data, f);
      var min = o.min != undefined ? o.min : d3.min(data, f);
      return [min, max];
    }
    
  });
})