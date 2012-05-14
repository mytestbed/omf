L.provide('OML.line_chart', ["graph/abstract_chart", "#OML.abstract_chart", "graph.css"], function () {

var o = OML;

  
  OML['line_chart'] = OML.abstract_chart.extend({
    decl_properties: [
      ['x_axis', 'key', {property: 'x'}], 
      ['y_axis', 'key', {property: 'y'}], 
      ['group_by', 'key', {property: 'id', optional: true}],             
      ['stroke_width', 'int', 2], 
      ['stroke_color', 'color', 'black'],
      ['stroke_fill', 'color', 'blue']
    ],
    
    base_css_class: 'oml-line-chart',
    
    configure_base_layer: function(vis) {
      //OML.abstract_chart.prototype.initialize.call(this, opts);
      var base_layer = this.base_layer = vis.append("svg:g")
                 .attr("transform", "translate(0, " + this.h + ")");


      var ca = this.chart_area; 
      //var g =  this.base_layer;
  
      this.legend_layer = base_layer.append("svg:g");
      var g = this.chart_layer = base_layer.append("svg:g");
      g.append("svg:line")
        .attr("class", "xAxis axis")      
        .attr("x1", ca.x)
        .attr("y1", -1 * ca.y)
        .attr("x2", ca.x + ca.w)
        .attr("y2", -1 * ca.y);
  
      g.append("svg:line")
        .attr("class", "yAxis axis")      
        .attr("x1", ca.x)
        .attr("y1", -1 * ca.y)
        .attr("x2", ca.x)
        .attr("y2", -1 * (ca.y + ca.h));
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

      /* GENERALIZE THIS */
      var stroke_color_f = d3.scale.category10();
      m.stroke_color = function(d, i) { 
        return stroke_color_f(i); 
      };
      
      //this.color = o['color'] || d3.scale.category10();
  
      /* 'data' should be an an array (each line) of arryas (each tuple)
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
      var x_max = this.x_max = o.xmax != undefined ? o.xmax : d3.max(data, function(d) {
        var last = d[d.length - 1];
        var x = x_index(last);
        return x;
      });
      var x_max_cnt = d3.max(data, function(d) {return d.length});
      var x_min = this.x_min = o.xmin != undefined ? o.xmin : d3.min(data, function(d) {return x_index(d[0]);});
      var x = this.x = d3.scale.linear().domain([x_min, x_max]).range([ca.x, ca.x + ca.w]);
  
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
  
  
      //    var x_min = this.x_min = d3.min(data, function(d) {return d3.min(d, function(d) {return d.x})});
      var y_max = this.y_max = o.ymax != undefined ? o.ymax : d3.max(data, function(s) {return d3.max(s, function(t) {return y_index(t)})});
      var y_min = this.y_min = o.ymin != undefined ? o.ymin : d3.min(data, function(s) {return d3.min(s, function(t) {return y_index(t)})});
      var y = this.y = d3.scale.linear().domain([y_min, y_max]).range([ca.y, ca.y + ca.h]);
  
  
      //var stroke_width = o.stroke_width ? o.stroke_width : 2;
      var line = d3.svg.line()
        .x(function(t) { return x(x_index(t)) })
        .y(function(t) { return -1 * y(y_index(t)); })
        ;
  
      var self = this;
      var lines = this.chart_layer.selectAll(".chart")
                    .data(data, function(d, i) { return i; })
                    .attr("d", function(d) { return line(d); });
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

  
      this.update_ticks();
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
  
    update_ticks: function() {
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
          .attr("class", "xTicks ticks")
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
          .attr("class", "yTicks ticks")
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
