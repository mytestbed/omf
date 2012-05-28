L.provide('OML.scatter_plot', ["graph/abstract_chart", "#OML.abstract_chart", "graph/axis", "#OML.axis"], function () {

  OML.scatter_plot = OML.abstract_chart.extend({
    decl_properties: [
      ['x_axis', 'key', {property: 'x'}], 
      ['y_axis', 'key', {property: 'y'}], 
      ['radius', 'int', 10],       
      ['stroke_width', 'int', 2], 
      ['stroke_color', 'color', 'black'],
      ['fill_color', 'color', 'orange']
    ],
    
    defaults: function() {
      return this.deep_defaults({
        relative: false,   // If true, report percentage
        axis: {
          orientation: 'horizontal'
        }
      }, OML.scatter_plot.__super__.defaults.call(this));      
    },    
    
    
    configure_base_layer: function(vis) {
      var base = this.base_layer = vis.append("svg:g")
                                      .attr("class", "scatterplot")
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
      var x_m = m.x_axis;
      var y_m = m.y_axis;
      var r_m = m.radius;

      var x_f = this.x_f = d3.scale.linear()
                          .domain(this.extent(data, x_m, o.mapping.x_axis))
                          .range([0, ca.w])
                          .nice();
      var y_f = this.y_f = d3.scale.linear()
                          .domain(this.extent(data, y_m, o.mapping.y_axis))
                          .range([0, ca.h])
                          .nice();
      var r_f = typeof(r_m) != 'function' ? d3.functor(r_m) : r_m;
      var w_f = typeof(r_m) != 'function' ? (2 * r_m) : function(d) { return 2 * r_m(d); }
                
      var x = function(d) { return x_f(x_m(d)) + ca.x - r_f(d); };
      var y = function(d) { return ca.ty + ca.h - y_f(y_m(d)) - r_f(d); };
      var rects = this.chart_layer.selectAll("rect").data(data);
      rects.enter().append("rect")
        .attr("x", x)
        .attr("y", y)
        .attr("width", w_f)
        .attr("height", w_f)
        .attr("stroke-width", m.stroke_width)
        .attr("stroke", m.stroke_color)
        .attr("fill", m.fill_color)
        ;
      rects.transition().duration(1000)
        .attr("x", x)
        .attr("y", y)
        .attr("width", w_f)
        .attr("height", w_f)
        .attr("stroke-width", m.stroke_width)
        .attr("stroke", m.stroke_color)
        .attr("fill", m.fill_color)
        ;

      rects.exit()
        .remove()
        ;
          
       this.redraw_axis(data, x_f, y_f);
    },
    
    redraw_axis: function(data, x, y) {
      var self = this;
      var ca = this.widget_area;
      var m = this.mapping;
      var oAxis = this.opts.axis || {};

      if (this.xAxis) {
        var xAxis = this.xAxis.scale(x);
        this.axis_layer.select('g.x.axis').call(xAxis);
      } else {
        var xAxis = this.xAxis = OML.line_chart2_axis(oAxis.x).scale(x).orient("bottom").range([0, ca.w]);      
        this.axis_layer
          .append('g')
            .attr("transform", "translate(" + ca.x + "," + (ca.ty + ca.h) + ")")
            .attr('class', 'x axis')
            .call(xAxis)
            ;
      }
      
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
    
    
    on_highlighted: function(evt) {
      var els = evt.elements;
      var piece_id = els[0].id
      var vis = this.chart_layer;
      vis.selectAll("path")
       .filter(function(d) {
         return d.value != piece_id;
       })
       .transition()
         .style("opacity", 0.3)
         .delay(0)
         .duration(300)
         ;
      if (evt.source == null) {
        evt.source = this;
        OHUB.trigger("graph.highlighted", evt);
      }
    },

    on_dehighlighted: function(evt) {
      var vis = this.chart_layer;
      vis.selectAll("path")
       .transition()
         .style("opacity", 1.0)         
         .delay(0)
         .duration(300)
      if (evt.source == null) {
        evt.source = this;
        OHUB.trigger("graph.dehighlighted", evt);
      }
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
