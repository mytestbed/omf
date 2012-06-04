L.provide('OML.holt_winters_chart', ["graph/line_chart2", "#OML.line_chart2"], function () {

  OML.holt_winters_chart = OML.line_chart2.extend({
    
    decl_properties: [  // need to find a way to also extend this properties from the superclass
      ['x_axis', 'key', {property: 'x'}], 
      ['y_axis', 'key', {property: 'y'}], 
      ['raw_stroke_width', 'int', 1], 
      ['raw_stroke_color', 'color', "#878787"],
      ['smooth_stroke_width', 'int', 3], 
      ['smooth_stroke_color', 'color', "#ff7f0e"],
      ['band_stroke_width', 'int', 1], 
      ['band_stroke_color', 'color', 'none'],
      ['band_fill_color', 'color', "#fff2d8"],      
    ],
    
    defaults: function() {
      return this.deep_defaults({
        smooth: {
          alpha: 0.1,
          beta: 0.1,
          lambda: 0.1,
          delta: 2.5
        },
        
      }, OML.line_chart2.__super__.defaults.call(this));      
    },    
    
    base_css_class: 'oml-holt-winters-chart',    
  
    redraw: function(data) {
      var self = this;
      var o = this.opts;
      var ca = this.widget_area;
      var m = this.mapping;
      
      var x_index = m.x_axis;
      var y_index = m.y_axis;

      var ctxt = {'s_old' : null, 'old' : null, 'a': 0, 'b': 0, 'c': 0, 'd': 0};
      var os = o.smooth;
      var alpha = os.alpha;
      var beta = os.beta;
      var lambda = os.lambda;
      var delta = os.delta;
      data = _.map(data, function(d) {
        var x = x_index(d);
        var y = y_index(d);
        if (ctxt.smooth) {
          // Calculate a, b, and c first, and use them to calculate the predicted (smoothed) value
          var a = ctxt.a = (alpha * (ctxt.old - ctxt.c)) + ((1 - alpha) * (ctxt.a + ctxt.b))
          var b = ctxt.b = (beta * (a - ctxt.a)) + ((1 - beta) * ctxt.b)
          var c = ctxt.c = (lambda * (ctxt.old - a)) + ((1-lambda) * ctxt.c)
          var smooth = ctxt.smooth = a + b + c;

          // Calculate the deviation, and use the last deviation to calculate the upper and lower bounds
          var upper_bound = smooth + (delta * ctxt.d);
          var lower_bound = smooth - (delta * ctxt.d);
          if (lower_bound < 0) lower_bound = 0;
          var d = ctxt.d = (lambda * Math.abs(y - smooth)) + ((1 - lambda) * ctxt.d);
        } else {
          // First timestep. Just use actual values
          var smooth = ctxt.smooth = y;
          var upper_bound = y;
          var lower_bound = y;
        }
        ctxt.old = y;
        return [x, y, smooth, upper_bound, lower_bound];
      }, this);
        
      // The following assumes that the data is sorted in ascending value for x_axis
      var o_xaxis = o.mapping.x_axis || {}
      var x_max = this.x_max = o_xaxis.max != undefined ? o_xaxis.max : data[data.length - 1][0];
      var x_min = this.x_min = o_xaxis.min != undefined ? o_xaxis.min : data[0][0];
      var x = this.x = d3.scale.linear().domain([x_min, x_max]).range([0, ca.w]).nice();
      
      // let's just use the raw data for getting the extent of y axis
      var y = this.y = d3.scale.linear()
                        .domain(this.extent(data, function(d) {return d[1]}))
                        .nice();
        
      this.redraw_axis(x, y);

      // *** LINES ****
      // In case the widget got resized
      this.chart_layer.attr("transform", "translate(" + ca.x + ", " + (this.h - ca.y) + ")");
      y.range([0, ca.h]);
      var self = this;
      
      // Confidence band
      this.chart_layer.selectAll(".band")
              .data([data])
              .enter()
              .append("svg:path")
                .attr("stroke-width", m.band_stroke_width)
                .attr("d", d3.svg.area()
                             .x(function(d) { return x(d[0]) })
                             .y0(function(d) { return -1 * y(d[3]); })
                             .y1(function(d) { return -1 * y(d[4]); }) 
                )
                .attr("class", "band")
                .attr("stroke", m.band_stroke_color)
                .attr("fill", m.band_fill_color)
                ;
                
      // raw measurements
      this.chart_layer.selectAll(".raw")
              .data([data])
              .enter()
              .append("svg:path")
                .attr("stroke-width", m.raw_stroke_width)
                .attr("d", d3.svg.line()
                            .x(function(d) { return x(d[0]) })
                            .y(function(d) { return -1 * y(d[1]); })
                )
                .attr("class", "raw")
                .attr("stroke", m.raw_stroke_color)
                .attr("fill", "none")
                ;
                
      // smoothed line
      this.chart_layer.selectAll(".smooth")
              .data([data])
              .enter()
              .append("svg:path")
                .attr("stroke-width", m.smooth_stroke_width)
                .attr("d", d3.svg.line()
                            .x(function(d) { return x(d[0]) })
                            .y(function(d) { return -1 * y(d[2]); })
                )
                .attr("class", "smooth")
                .attr("stroke", m.smooth_stroke_color)
                .attr("fill", "none")
                ;
      
     
      this.update_selection({});
    },
    
  })
})

/*
  Local Variables:
  mode: Javascript
  tab-width: 2
  indent-tabs-mode: nil
  End:
*/
