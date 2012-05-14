L.provide('OML.pie_chart', ["graph/abstract_chart", ["/resource/vendor/d3/d3.js", "/resource/vendor/d3/d3.layout.js"], "#OML.abstract_chart"], function () {

var o = OML;

  
  OML['pie_chart'] = OML.abstract_chart.extend({
    decl_properties: [
      ['value', 'key', {property: 'value'}], 
//      ['group_by', 'key', {property: 'id', optional: true}],             
      ['stroke_width', 'int', 2], 
      ['stroke_color', 'color', 'white'],
      ['fill_color', 'color', 'category20()'],
      ['label', 'key', {optional: true}]
    ],
    
    configure_base_layer: function(vis) {
      this.legend_layer = vis.append("svg:g");
      this.chart_layer = vis.append("svg:g");
    },
    
    base_css_class: 'oml-pie-chart',
    
  
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
      var w = ca.w,
          h = ca.h,
          r = Math.min(w, h) / 2;
          
      var arc = d3.svg.arc().innerRadius(r * .6).outerRadius(r);
      var sa = arc.startAngle();
      
      var self = this;
                
      var vis = this.chart_layer
          .data([data])
          ;
      var arcs = vis.selectAll("g.arc")
          .data(d3.layout.pie().value(m.value))
        .enter().append("g")
          .attr("class", "arc")
          .attr("transform", "translate(" + (r + ca.x) + "," + (r + ca.y) + ")");          
      
      arcs.append("path")
          .attr("fill", function(d, i) { 
            return m.fill_color(i); 
          })
          .attr("d", arc)
          .attr("stroke", m.stroke_color)
          .attr('stroke-width', m.stroke_width)
          ;
      
      var text_f = m.label;
      if (m.label) {
        text_f = function(d) { return m.label(d.data); };
      } else {
        text_f = function(d) { return d.value.toFixed(2); };
      }
      arcs.append("text")
          .attr("transform", function(d) { return "translate(" + arc.centroid(d) + ")"; })
          .attr("dy", ".35em")
          .attr("text-anchor", "middle")
          .attr("display", function(d) { return d.value > .15 ? null : "none"; })
          .text(text_f);
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
    
  
  
  })
})

/*
  Local Variables:
  mode: Javascript
  tab-width: 2
  indent-tabs-mode: nil
  End:
*/
