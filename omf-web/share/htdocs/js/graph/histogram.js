
L.provide('OML.histogram', ["graph/abstract_chart", "#OML.abstract_chart", "graph/axis", "#OML.axis",
//                              ["/resource/vendor/d3/d3.js", "/resource/vendor/d3/d3.layout.js"]], 
                              ["/resource/vendor/d3/d3.js"]], 
  function () {

  OML['histogram'] = OML.abstract_chart.extend({
    decl_properties: [
      ['value', 'float', {property: 'value'}], 
      // ['x_axis', 'key', {property: 'x'}], 
      // ['y_axis', 'key', {property: 'y'}], 
      // ['group_by', 'key', {property: 'id', optional: true}],             
      ['stroke_width', 'int', 2], 
      ['stroke_color', 'color', 'white'],
      ['fill_color', 'color', 'blue']
    ],
    
    defaults: function() {
      //var d = OML.histogram.__super__.defaults.call(this);
      return this.deep_defaults({
        //bins: 5, // specify the number of bins to be used in the histogram
        unique: false, // If true, buckets are defined by unique 'values'
        axis: {
          x: {
            ticks: {
              format: ",.2f"
            }
          }
        }
      }, OML.histogram.__super__.defaults.call(this));      
    },    
    
    base_css_class: 'oml-line-chart',
    
    // initialize: function(opts) {
      // var o = OML.histogram.__super__.defaults.call(this);
      // OML.histogram.__super__.initialize.call(this, opts);
    // },    

    configure_base_layer: function(vis) {
      var base = this.base_layer = vis.append("svg:g")
                                      .attr("class", "histogram")
                                      ;
                 //.attr("transform", "translate(0, " + this.h + ")");

      var ca = this.chart_area; 
      this.legend_layer = base.append("svg:g");
      this.chart_layer = base.append("svg:g");
      this.axis_layer = base.append('g');
    },
    
    redraw: function(data) {
      var self = this;
      var o = this.opts;
      var ca = this.widget_area;
      var m = this.mapping;

      var hdata;      
      // if (o.unique) {
        // hdata = this.unique_histogram(data);
      // } else {
        var histogram = d3.layout.histogram();
        histogram.value(m.value);
        var bins = o.bins ? histogram.bins(o.bins) : histogram.bins();
        if (o.density != 'undefined"') histogram.frequency(! o.density);
        hdata = histogram(data);
      // }
      
      var u = _.map(_.uniq(data, false, m.value), m.value).sort();      

      var x = d3.scale.ordinal()
          .domain(hdata.map(function(d) { 
            return d.x; 
          }))
          .rangeRoundBands([0, ca.w]);
       
      var y = d3.scale.linear()
          .domain([0, d3.max(hdata.map(function(d) { return d.y; }))])
          .range([0, ca.h])
          .nice()
          ;

      this.chart_layer.selectAll("rect")
          .data(hdata)
        .enter().append("rect")
          .attr("width", x.rangeBand())
          .attr("x", function(d) { return x(d.x) + ca.x; })
          .attr("y", function(d) { return ca.ty + ca.h - y(d.y); })
          .attr("height", function(d) { return y(d.y); })
          .attr("stroke-width", m.stroke_width)
          .attr("stroke", m.stroke_color)
          .attr("fill", m.fill_color)
          ;

      var oAxis = o.axis || {};
      
      // Create an X axis with ticks at the boundaries of the bar charts
      //
      var ticks = hdata.map(function(d) { return d.x - 0.5 * d.dx; });
      var xmin = ticks[0];
      var xmax = d3.max(hdata.map(function(d) { return d.x + 0.5 * d.dx; }));
      ticks.push(xmax);
      var ax_f = d3.scale.linear()
          .domain([xmin, xmax])
          .range([0, ca.w])
          ;           
      if (this.xAxis) {
        var xAxis = this.xAxis.scale(ax_f).tick_values(ticks);
        this.axis_layer.select('g.x.axis').call(xAxis);
      } else {
        var xAxis = this.xAxis = OML.line_chart2_axis(oAxis.x).scale(ax_f).tick_values(ticks).orient("bottom").range([0, ca.w]);      
        this.axis_layer
          .append('g')
            .attr("transform", "translate(" + ca.x + "," + (ca.ty + ca.h) + ")")
            .attr('class', 'x axis')
            .call(xAxis)
            ;
      }
      
      // Y axis is normal
      //
      var inv_y = y.range([ca.h, 0]);
      if (this.yAxis) {
        var yAxis = this.yAxis.scale(inv_y);
        this.axis_layer.select('g.y.axis').call(yAxis);
      } else {
        var yAxis = this.yAxis = OML.line_chart2_axis(oAxis.y).scale(inv_y).orient("left").range([0, ca.h]);
        this.axis_layer
          .append('g')
            .attr("transform", "translate(" + ca.x + "," + ca.ty + ")")
            .attr('class', 'y axis')
            .call(yAxis)
            ;
      }
                 
      
    },

    // Calculate the 'histogram' over 'data' assuming that applying the 'value' operator
    // over 'data' provides a limited number of unique values which are treated as the bins.
    //
    unique_histogram: function(data) {
      var self = this;
      var o = this.opts;
      var ca = this.widget_area;
      var value_f = this.mapping.value;
      
      var h = {};
      var count = 0;
      _.map(data, function(s) {
        var key = value_f(s);
        count = count + 1;
        h[key] = 1 + (h[key] || 0);
      })
      var buckets = _.keys(h).sort();
      var result = _.map(buckets, function(k) { return h[k]; });
      var i = 0;
    },
    
    // redraw2: function(data) {
      // var self = this;
      // var o = this.opts;
      // var ca = this.widget_area;
      // var m = this.mapping;
//       
      // /* 'data' should be an an array (each line) of arrays (each tuple)
       // * The following code assumes that the tuples are sorted in ascending 
       // * value associated with the x-axis. 
       // */
      // // var x_index = m.x_axis;
      // // var y_index = m.y_axis;
      // // var group_by = m.group_by;
      // // if (group_by != null) {
        // // data = this.group_by(data, group_by);
      // // } else {
        // // data = [data];
      // // }
// 
      // var histogram = d3.layout.histogram();
      // var x = d3.scale.ordinal();
      // var y = d3.scale.linear();
      // //xAxis = d3.svg.axis().scale(x).orient("bottom").tickSize(6, 0);
//           
      // histogram.value(m.value);
      // data = histogram(data);
// 
      // // Update the x-scale.
      // x.domain(data.map(function(d) { return d.x; }))
          // .rangeRoundBands([0, ca.w], .1);
// 
      // // Update the y-scale.
      // y.domain([0, d3.max(data, function(d) { return d.y; })])
          // .range([ca.h, 0]);
// 
      // // Select the svg element, if it exists.
      // var svg = this.chart_layer.selectAll(".chart").data([data]);
// 
      // // Otherwise, create the skeletal chart.
      // var gEnter = svg.enter().append("svg").append("g");
      // gEnter.append("g").attr("class", "bars");
      // gEnter.append("g").attr("class", "x axis");
// 
      // // // Update the outer dimensions.
      // // svg .attr("width", width)
          // // .attr("height", height);
// // 
      // // // Update the inner dimensions.
      // var g = svg.select("g")
          // .attr("transform", "translate(" + ca.x + "," + ca.y + ca.h + ")");
// 
      // // Update the bars.
      // var bar = svg.select(".bars").selectAll(".bar").data(data);
      // bar.enter().append("rect");
      // bar.exit().remove();
      // bar .attr("width", x.rangeBand())
          // .attr("x", function(d) { return x(d.x); })
          // .attr("y", function(d) { return y(d.y); })
          // .attr("height", function(d) { return y.range()[0] - y(d.y); })
          // .order();
//           
// 
      // // Update the x-axis.
      // // g.select(".x.axis")
          // // .attr("transform", "translate(0," + y.range()[0] + ")")
          // // .call(xAxis);
    // }

  }) // end of histogram
}) // end of provide
