//L.provide('OML.axis', ["graph.css", ["/resource/vendor/d3/d3.js", "/resource/vendor/d3/d3.time.js"]], function () {
L.provide('OML.axis', ["graph.css", "/resource/vendor/d3/d3.js"], function () {  

  OML.line_chart2_axis = function(options) {
    if (!options) options = {};
    
    var d3_axis = d3.svg.axis();

    var defaults = {
      legend: {
        text: 'DESCRIBE ME',
        offset: 40 
      },
      ticks: {
        // type: 'date',
        // format: '%I:%M', // hour:minutes
        // format: ",.0f" // integers with comma-grouping for thousands.
        transition: 500  // smoothly transition the ticks when they change
      }      
    };

    var orient = 'bottom';
    var scale;
    var range = [0, 100]; // default range, should be set specifically
    var opts = _.defaults((options || {}), defaults);
    
    // LEGEND
    var ol = options.legend;
    ol = ol ? (typeof(ol) === "string" ? {text: ol} : ol) : {};
    options.legend = _.defaults(ol, defaults.legend); 
    
    // TICKS
    var ot = options.ticks = _.defaults(options.ticks, defaults.ticks);
    // Check if we need a special formatter for the tick labels
    if (ot.type == 'date' || ot.type == 'dateTime') {
      var d_f = d3.time.format(ot.format || "%X");
      d3_axis.tickFormat(function(d) {
        var date = new Date(1000 * d);  // TODO: Implicitly assuming that value is in seconds is most likely NOT a good idea
        var fs = d_f(date); 
        return fs;
      });
    } else if (ot.type == 'key') {
      var lm = ot.key_map;
      d3_axis.tickFormat(function(d) {
        var l = lm[d] || ('??-' + d);
        return l;
      });
      
    } else if (ot.format) {
      d3_axis.tickFormat(d3.format(ot.format));
    }
        
    
    function axis(selection) {
      selection.each(function(data) {
        var o = opts;
        var layer = d3.select(this);
        var ol = opts.legend
        var axisLabel = d3.select(this).selectAll('text.axis_legend')
            .data([ol.text]);
        switch (orient) {
          case 'bottom':
            axisLabel.enter().append('text').attr('class', 'axis_legend')
                .attr('text-anchor', 'middle')
                .attr('y', ol.offset);
            axisLabel
                .attr('x', (range[1] - range[0]) / 2);
                break;
          case 'left':
            axisLabel.enter().append('text').attr('class', 'axis_legend')
                .attr('transform', 'rotate(-90)')
                .attr('y', -1 * ol.offset); 
            axisLabel
                .attr('x', -1 * (range[1] - range[0]) / 2);
                break;
        }
        axisLabel.exit().remove();
        axisLabel
            .text(function(d) { return d });

        // TICKS  
        var ot = opts.ticks;
        var tl = ot.transition ? layer.transition().duration(ot.transition) : layer;
        tl.call(d3_axis);
        
        // d3.select(this).selectAll('line.tick')
          // //.filter(function(d) { return !parseFloat(d) })
          // .filter(function(d) {
            // //this is because sometimes the 0 tick is a very small fraction, TODO: think of cleaner technique 
            // var v = !parseFloat(Math.round(d*100000)/1000000);
            // return v; 
          // }) 
          // .classed('zero', true);
      });
      return axis;
    }      
    
    axis.orient = function(_) {
      if (!arguments.length) return orient;
      orient = _;
      d3_axis.orient(orient);
      return axis;
    };
    
    axis.range = function(_) {
      if (!arguments.length) return range;
      range = _;
      return axis;
    };
    
    axis.scale = function(_) {
      if (!arguments.length) return scale;
      scale = _;
      d3_axis.scale(scale);
      return axis;
    };
    
    axis.tick_values = function(_) {
      if (!arguments.length) return scale;
      values = _;
      d3_axis.tickValues(values);
      return axis;
    };
    
    return axis;
  }
})

/*
  Local Variables:
  mode: Javascript
  tab-width: 2
  indent-tabs-mode: nil
  End:
*/
