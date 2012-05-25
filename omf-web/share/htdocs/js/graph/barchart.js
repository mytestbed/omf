
L.provide('OML.barchart', ["graph/abstract_chart", "#OML.abstract_chart", "graph/axis", "#OML.axis",
//                              ["/resource/vendor/d3/d3.js", "/resource/vendor/d3/d3.layout.js"]], 
                              ["/resource/vendor/d3/d3.js"]], 
  function () {

  OML.barchart = OML.abstract_chart.extend({
    decl_properties: [
      ['key', 'int', {property: 'key'}], 
      ['value', 'float', {property: 'value'}], 
      // ['x_axis', 'key', {property: 'x'}], 
      // ['y_axis', 'key', {property: 'y'}], 
      // ['group_by', 'key', {property: 'id', optional: true}],             
      ['stroke_width', 'int', 2], 
      ['stroke_color', 'color', 'white'],
      ['fill_color', 'color', 'blue']
    ],
    
    defaults: function() {
      return this.deep_defaults({
        relative: false,   // If true, report percentage
        axis: {
          orientation: 'horizontal'
        }
      }, OML.barchart.__super__.defaults.call(this));      
    },    
    
    base_css_class: 'oml-barchart',
    
    // initialize: function(opts) {
    // },    

    configure_base_layer: function(vis) {
      var base = this.base_layer = vis.append("svg:g")
                                      .attr("class", "barchart")
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

      var h = {};
      var key_f = m.key;
      var value_f = m.value;
      var sum = 0;
      _.map(data, function(s) {
        var key = key_f(s);
        var value = value_f(s);
        sum = sum + value;
        h[key] = value + (h[key] || 0);
      })
      var keys = _.keys(h).sort();
      var bdata;
      if (o.relative) {
        var frac = 1.0 / sum;
        bdata = _.map(keys, function(k) { return [k, frac * h[k]]; });
      } else {
        bdata = _.map(keys, function(k) { return [k, h[k]]; });
      }
      
      var x = d3.scale.ordinal()
          .domain(bdata.map(function(d) { 
            return d[0]; 
          }))
          .rangeRoundBands([0, ca.w]);
       
      var y = d3.scale.linear()
          .domain([0, d3.max(bdata.map(function(d) { return d[1]; }))])
          .range([0, ca.h])
          .nice()
          ;

      this.chart_layer.selectAll("rect")
          .data(bdata)
        .enter().append("rect")
          .attr("width", x.rangeBand())
          .attr("x", function(d) { return x(d[0]) + ca.x; })
          .attr("y", function(d) { return ca.ty + ca.h - y(d[1]); })
          .attr("height", function(d) { return y(d[1]); })
          .attr("stroke-width", m.stroke_width)
          .attr("stroke", m.stroke_color)
          .attr("fill", m.fill_color)
          ;
          
       this.redraw_axis(bdata, keys, x, y);
    },
    
    redraw_axis: function(bdata, ticks, x, y) {
      var self = this;
      var ca = this.widget_area;
      var m = this.mapping;
      var oAxis = this.opts.axis || {};
      
      // Create an X axis with ticks at the boundaries of the bar charts
      //
      var ax_f = d3.scale.ordinal()
          .domain(ticks)
          .rangePoints([0, ca.w], 1.0)
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


  }) // end of histogram
}) // end of provide
