L.provide('OML.pie_chart', ["graph/abstract_chart", "#OML.abstract_chart"], function () {

var o = OML;

  
  OML.pie_chart = OML.abstract_chart.extend({
    decl_properties: [
      ['value', 'key', {property: 'value'}], 
//      ['group_by', 'key', {property: 'id', optional: true}],             
      ['stroke_width', 'int', 2], 
      ['stroke_color', 'color', 'white'],
      ['fill_color', 'color', 'category20()'],
      ['label', 'key', {optional: true}]
    ],
    
    defaults: function() {
      return this.deep_defaults({
        inner_radius: 0.4 // size of donought hole in the middle
      }, OML.pie_chart.__super__.defaults.call(this));      
    },    
    
    configure_base_layer: function(vis) {
      this.legend_layer = vis.append("svg:g");
      this.chart_layer = vis.append("svg:g");
    },
    
    base_css_class: 'oml-pie-chart',
    
    redraw: function(data) {
      var self = this;      
      var o = this.opts;
      var ca = this.widget_area;
      var m = this.mapping;
      var w = ca.w,
          h = ca.h,
          r = Math.min(w, h) / 2;
          
      var arc = d3.svg.arc().outerRadius(r);
      var i_r = o.inner_radius;
      if (i_r > 0) {
        if (i_r < 1) {
          i_r = i_r * r; // fractional
        }
        arc.innerRadius(i_r);
      }
      var sa = arc.startAngle();
      
      var self = this;
                
      var vis = this.chart_layer
          .data([data])
          ;
      var arcs = vis.selectAll("g.arc")
          .data(d3.layout.pie().value(m.value))
        .enter().append("g")
          .attr("class", "arc")
          //.attr("transform", "translate(" + (r + ca.x) + "," + (r + ca.ty) + ")");          
          .attr("transform", "translate(" + (w / 2 + ca.x) + "," + (h / 2 + ca.ty) + ")");          
      
      arcs.append("path")
          .attr("fill", function(d, i) { 
            return m.fill_color(i); 
          })
          .attr("d", arc)
          .attr("stroke", m.stroke_color)
          .attr('stroke-width', m.stroke_width)
          .on("mouseover", function(data) {
            self.on_highlighted({'elements': [{'id': data.value}]});
          })
          .on("mouseout", function() {
            self.on_dehighlighted({});
          })                   
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
