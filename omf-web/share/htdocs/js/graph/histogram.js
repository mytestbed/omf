
L.provide('OML.histogram', ["graph/abstract_chart", "#OML.abstract_chart", 
                              ["/resource/vendor/d3/d3.js", "/resource/vendor/d3/d3.layout.js"]], 
  function () {

  OML['histogram'] = OML.abstract_chart.extend({
    decl_properties: [
      ['value', 'float', {property: 'value'}], 
      // ['x_axis', 'key', {property: 'x'}], 
      // ['y_axis', 'key', {property: 'y'}], 
      // ['group_by', 'key', {property: 'id', optional: true}],             
      // ['stroke_width', 'int', 2], 
      // ['stroke_color', 'color', 'black'],
      // ['stroke_fill', 'color', 'blue']
    ],
    
    base_css_class: 'oml-line-chart',

    configure_base_layer: function(vis) {
      var base_layer = this.base_layer = vis.append("svg:g")
                 .attr("transform", "translate(0, " + this.h + ")");

      var ca = this.chart_area; 
      this.legend_layer = base_layer.append("svg:g");
      this.chart_layer = base_layer.append("svg:g");
    },
    
    redraw: function() {
      var self = this;
      
      var data;
      if ((data = this.data_source.events) == null) {
        throw "Missing events array in data source"
      }
      if (data.length == 0) return;
      
      var o = this.opts;
      var ca = this.chart_area;
      var m = this.mapping;
      
      /* 'data' should be an an array (each line) of arrays (each tuple)
       * The following code assumes that the tuples are sorted in ascending 
       * value associated with the x-axis. 
       */
      // var x_index = m.x_axis;
      // var y_index = m.y_axis;
      // var group_by = m.group_by;
      // if (group_by != null) {
        // data = this.group_by(data, group_by);
      // } else {
        // data = [data];
      // }

      var histogram = d3.layout.histogram(),
          x = d3.scale.ordinal(),
          y = d3.scale.linear(),
          xAxis = d3.svg.axis().scale(x).orient("bottom").tickSize(6, 0);
          
      histogram.value(m.value);
      data = histogram(data);

      // Update the x-scale.
      x.domain(data.map(function(d) { return d.x; }))
          .rangeRoundBands([0, ca.w], .1);

      // Update the y-scale.
      y.domain([0, d3.max(data, function(d) { return d.y; })])
          .range([ca.h, 0]);

      // Select the svg element, if it exists.
      var svg = this.chart_layer.selectAll(".chart").data([data]);

      // Otherwise, create the skeletal chart.
      var gEnter = svg.enter().append("svg").append("g");
      gEnter.append("g").attr("class", "bars");
      gEnter.append("g").attr("class", "x axis");

      // // Update the outer dimensions.
      // svg .attr("width", width)
          // .attr("height", height);
// 
      // // Update the inner dimensions.
      var g = svg.select("g")
          .attr("transform", "translate(" + ca.x + "," + ca.y + ca.h + ")");

      // Update the bars.
      var bar = svg.select(".bars").selectAll(".bar").data(data);
      bar.enter().append("rect");
      bar.exit().remove();
      bar .attr("width", x.rangeBand())
          .attr("x", function(d) { return x(d.x); })
          .attr("y", function(d) { return y(d.y); })
          .attr("height", function(d) { return y.range()[0] - y(d.y); })
          .order();

      // Update the x-axis.
      g.select(".x.axis")
          .attr("transform", "translate(0," + y.range()[0] + ")")
          .call(xAxis);
    }

  }) // end of histogram
}) // end of provide
