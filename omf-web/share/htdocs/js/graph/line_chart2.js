L.provide('OML.line_chart2', ["graph/abstract_chart", "#OML.abstract_chart", "graph/axis", "#OML.axis", "graph.css", "/resource/vendor/d3/d3.js"], function () {

var o = OML;

  
  OML['line_chart2'] = OML.abstract_chart.extend({
    decl_properties: [
      ['x_axis', 'key', {property: 'x'}], 
      ['y_axis', 'key', {property: 'y'}], 
      ['group_by', 'key', {property: 'id', optional: true}],             
      ['stroke_width', 'int', 2], 
      ['stroke_color', 'color', 'category10()'],
      ['stroke_fill', 'color', 'blue']
    ],
    
    base_css_class: 'oml-line-chart',
    
    configure_base_layer: function(vis) {
      //OML.abstract_chart.prototype.initialize.call(this, opts);
      var base_layer = this.base_layer = vis.append("svg:g")
                 ;

      var ca = this.widget_area; 
      this.legend_layer = base_layer.append("svg:g");
      this.chart_layer = base_layer.append("svg:g")
                                    .attr("transform", "translate(" + ca.x + ", " + (this.h - ca.y) + ")");
      this.axis_layer = base_layer.append('g');
    },
    
  
    redraw: function(data) {
      var self = this;
      var o = this.opts;
      var ca = this.widget_area;
      var m = this.mapping;
  
      /* 'data' should be an an array (each line) of arrays (each tuple)
       * The following code assumes that the tuples are sorted in ascending 
       * value associated with the x-axis. 
       */
      var x_index = m.x_axis;
      var y_index = m.y_axis;
      var group_by = m.group_by;
      if (group_by != null) {
        data = this.group_by(data, group_by);
      } else {
        data = [data];
      };
      
      // The following assumes that the data is sorted in ascending value for x_axis
      var o_xaxis = o.mapping.x_axis || {}
      var x_max = this.x_max = o_xaxis.max != undefined ? o_xaxis.max : d3.max(data, function(d) {
        var last = d[d.length - 1];
        var x = x_index(last);
        return x;
      });
      var x_max_cnt = d3.max(data, function(d) {return d.length});
      var x_min = this.x_min = o_xaxis.min != undefined ? o_xaxis.min : d3.min(data, function(d) {return x_index(d[0]);});
      var x = this.x = d3.scale.linear().domain([x_min, x_max]).range([0, ca.w]).nice();
  
      if (x_max_cnt > ca.w) {
        // To much data, downsample
        var data2 = [];
        data.map(function(l) {
            var xcurr = -999999;
            var l2 = [];
            l.map(function(t) {
                var x = Math.round(self.x(x_index(t)));
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
  
  
      // var y_max = this.y_max = o.ymax != undefined ? o.ymax : d3.max(data, function(s) {return d3.max(s, function(t) {return y_index(t)})});
      // var y_min = this.y_min = o.ymin != undefined ? o.ymin : d3.min(data, function(s) {return d3.min(s, function(t) {return y_index(t)})});
      // var y_ext = this.extent_2d(data, y_index, o.y_axis);
      var y = this.y = d3.scale.linear()
                        // .domain([y_min, y_max])
                        .domain(this.extent_2d(data, y_index, o.mapping.y_axis))
                        .range([0, ca.h])
                        .nice();
        
      var line = d3.svg.line()
        .x(function(t) { return x(x_index(t)) })
        .y(function(t) { return -1 * y(y_index(t)); })
        ;
  
      // In case the widget got resized
      this.chart_layer.attr("transform", "translate(" + ca.x + ", " + (this.h - ca.y) + ")");
        
      var self = this;
      var lines = this.chart_layer.selectAll(".chart")
                    .data(data, function(d, i) { return i; })
                    ;
                    
      lines.transition().duration(0).attr("d", function(d) { return line(d); });
      lines.enter()
        .append("svg:path")
          .attr("stroke-width", m.stroke_width)
          .attr("d", function(d) {
              var l = line(d);
              return l;
            })
          .attr("class", "chart")
          .attr("stroke", m.stroke_color)
          .attr("fill", "none")
          .on("mouseover", function(data) {
            var group_by = self.mapping.group_by;
            if (group_by) {
              var name = group_by(data[0]);
              self.on_highlighted({'elements': [{'id': name}]});
            }
          })
          .on("mouseout", function() {
            self.on_dehighlighted({});
          })         
          ;
      lines.exit().remove();
         
      var oAxis = o.axis || {};

      if (this.xAxis) {
        var xAxis = this.xAxis.scale(x).range([0, ca.w]);
        this.axis_layer.select('g.x.axis')
              .attr("transform", "translate(" + ca.x + "," + (ca.ty + ca.h) + ")")
              .call(xAxis);
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
        var yAxis = this.yAxis.scale(inv_y).range([0, ca.h]);
        this.axis_layer.select('g.y.axis')
                .attr("transform", "translate(" + ca.x + "," + ca.ty + ")")
                .call(yAxis);
      } else {
        var yAxis = this.yAxis = OML.line_chart2_axis(oAxis.y).scale(inv_y).orient("left").range([0, ca.h]);
        this.axis_layer
          .append('g')
            .attr("transform", "translate(" + ca.x + "," + ca.ty + ")")
            .attr('class', 'y axis')
            .call(yAxis)
            ;
      }
      this.update_selection({});
    },
    
    on_highlighted: function(evt) {
      var els = evt.elements;
      var names = _.map(els, function(el) { return el.id});
      var vis = this.chart_layer;
      var group_by = this.mapping.group_by;
      if (group_by) {
        vis.selectAll(".chart")
         .filter(function(d) {
           var dname = group_by(d[0]);
           return ! _.include(names, dname);
         })
         .transition()
           .style("opacity", 0.1)
           .delay(0)
           .duration(300);
      }
      if (evt.source == null) {
        evt.source = this;
        OHUB.trigger("graph.highlighted", evt);
      }
    },

    on_dehighlighted: function(evt) {
      var vis = this.chart_layer;
      vis.selectAll(".chart")
       .transition()
         .style("opacity", 1.0)         
         .delay(0)
         .duration(300)
      if (evt.source == null) {
        evt.source = this;
        OHUB.trigger("graph.dehighlighted", evt);
      }
    },
    
  
    clear: function(data) {
      this.data = null;
      var lines = this.chart_layer.selectAll(".chart")
                    .data([])
                    .exit().remove();
    },
    
    // Return a subset of the associated data set where the value mapped
    // to the x-axis is within the <+min+, +max> range.
    //
    filter_x: function(min, max) {
      var xi = this.mapping.x_axis;
      return this.data.filter(function(t) {
        var x = t[xi];
        return (x > min && x <= max);
      })
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
