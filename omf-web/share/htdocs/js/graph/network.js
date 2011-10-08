L.provide('OML.network', ["d3/d3"], function () {

  if (typeof(OML) == "undefined") OML = {};
    
  OML['network'] = function(opts) { 
    this.opts = opts || {};
    this.data = null;
    
    this.init = function() {
      var o = this.opts;
  
      var w = this.w = o['width'] || 700;
      var h = this.h = o['height'] || 400;
  
      var m = o['margin'] || {};
      var ml = m['left'] || 30;
      var mt = m['top'] || 20;
      var mr = m['right'] || 20;
      var mb = m['bottom'] || 20;
      var ca = this.chart_area = {x: ml, y: mb, w: w - ml - mr, h: h - mt - mb};
  
      var offset = o['offset'] || [0, 0];
  
      this.color = o['color'] || d3.scale.category10();
  
  
      var vis = this.init_svg(w, h);
      
      var g =  this.base_layer = vis.append("svg:g")
                 .attr("transform", "translate(0, " + h + ")")
                 ;
  
      this.graph_layer = g.append("svg:g");
      var data = this.data = o.data;
      if (data) this.redraw();
    };
  
    this.append = function(a_data) {
      var data = this.data;
      data.nodes = $.extend(data.nodes, a_data.nodes);
      data.links = $.extend(data.links, a_data.links);      
      this.redraw();   
    };

    this.update = function(data) {
      this.data = data;
      this.redraw();
    };
    
    this.redraw = function() {
      var self = this;
      var data = this.data;
      var o = this.opts;
      var ca = this.chart_area;
      
      var x = function(d) {
        var x = d.x * ca.w + ca.x;
        return x;
      };
      var y = function(d) {
        var y = -1 * (d.y * ca.h + ca.y);
        return y;
      };
      var c = d3.scale.linear()
          .domain([0, 0.8, 1])
          .range(["green", "yellow", "red"]);
          
      var vis = this.base_layer;
      var link = vis.selectAll("line.link")
        .data(d3.values(data.links))
          .style("stroke", function(d) { return c(d.load); })
          .style("stroke-width", function(d) { return d.w = 10 * d.load; })
          .attr("x1", function(d) { return x(data.nodes[d.from]); })
          .attr("y1", function(d) { return y(data.nodes[d.from]); })
          .attr("x2", function(d) { return x(data.nodes[d.to]); })
          .attr("y2", function(d) { return y(data.nodes[d.to]); })
        .enter().append("svg:line")
          .attr("class", "link")
          .style("stroke", function(d) { return c(d.load); })
          .style("stroke-width", function(d) { return d.w = 10 * d.load; })
          .attr("x1", function(d) { return x(data.nodes[d.from]); })
          .attr("y1", function(d) { return y(data.nodes[d.from]); })
          .attr("x2", function(d) { return x(data.nodes[d.to]); })
          .attr("y2", function(d) { return y(data.nodes[d.to]); })
          .on("mouseover", function() {
            d3.select(this).transition()
             .style("stroke-width", function(d) {
               return d.w + 3
             })
            .delay(0)
            .duration(300)
          })
          .on("mouseout", function() {
            d3.select(this).transition()
             .style("stroke-width", function(d) {return d.w})
             .delay(0)
             .duration(300)
          })
          ;

     var node = vis.selectAll("circle.node")
       .data(d3.values(data.nodes))
         .attr("cx", function(d) { return x(d); })
         .attr("cy", function(d) { return y(d); })
          .attr("r", function(d) {
            return d.r = d.capacity * 10 + 3;
          })
          .style("fill", function(d) { return c(d.capacity); })
       .enter().append("svg:circle")
         .attr("class", "node")
         .attr("cx", function(d) { return x(d); })
         .attr("cy", function(d) { return y(d); })
         .attr("r", function(d) {
            return d.r = d.capacity * 10 + 3;
          })
         .style("fill", function(d) { return c(d.capacity); })
         .style("stroke", "gray")
         .style("stroke-width", 1)
         .attr("fixed", true)
         //.call(force.drag)
         .on("mouseover", function() {
            d3.select(this).transition()
             .attr("r", function(d) {return d.r + 2 ;})
            .style("stroke", "black")
             .style("stroke-width", 3)
             .delay(0)
             .duration(300)
         })
         .on("mouseout", function() {
            d3.select(this).transition()
             .style("stroke", "gray")
             .style("stroke-width", 1)
             .attr("r", function(d) {return d.r;})
             .delay(0)
             .duration(300)
         })
       .transition()
          .attr("r", function(d) {
            return d.r = d.capacity * 10 + 3;
          })
          .delay(0)
       ;      
    };
     
    this.init_svg = function(w, h) {
      var opts = this.opts;

      //if (opts.svg) return opts.svg;
      
      var base_el = opts.base_el || "body";
      if (typeof(base_el) == "string") base_el = d3.select(base_el);
      var vis = opts.svg = base_el.append("svg:svg")
        .attr("width", w)
        .attr("height", h)
        .attr('class', 'oml-network');
      return vis;
    }
  
    this.init(opts);
  };
})


/*
  Local Variables:
  mode: Javascript
  tab-width: 2
  indent-tabs-mode: nil
  End:
*/