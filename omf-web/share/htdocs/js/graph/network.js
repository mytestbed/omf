L.provide('OML.network', ["d3"], function () {

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
      // g.append("svg:line")
        // .attr("x1", ca.x)
        // .attr("y1", -1 * ca.y)
        // .attr("x2", ca.x + ca.w)
        // .attr("y2", -1 * ca.y);
//   
      // g.append("svg:line")
        // .attr("x1", ca.x)
        // .attr("y1", -1 * ca.y)
        // .attr("x2", ca.x)
        // .attr("y2", -1 * (ca.y + ca.h));
  
      //this.process_schema();
      var data = o.data;
      if (data) this.update(data);
    };
  
    this.append = function(data) {
      this.update(data);      
    };
    
    this.update = function(data) {
      var self = this;
      this.data = data;
      var o = this.opts;
      var ca = this.chart_area;
  
      /* 'data' should be an an array (each line) of arryas (each tuple)
       * The following code assumes that the tuples are sorted in ascending 
       * value associated with the x-axis. 
       */
      
// var c = d3.scale.linear().range([
     // "rgb(0, 88, 36)",
     // "rgb(255, 255, 204)",
     // "rgb(227, 26, 28)"
   // ]).domain([0, 0.5, 1]);
var c = d3.scale.linear()
    .domain([-1, 0, 1])
    .range(["red", "white", "green"]);
    
var c = d3.scale.linear()
    .domain([0, 1])
    .range(["blue", "red"]);




var vis = this.base_layer;


    var link = vis.selectAll("line.link")
        .data(data.links)
        .style("stroke", function(d) { return c(d.load); })
        .style("stroke-width", function(d) { return d.w = 10 * d.load; })
        .enter().append("svg:line")
        .attr("class", "link")
        .style("stroke-width", function(d) {
           return d.w = 10 * d.load;
        })
        .style("stroke", function(d) {
          var col = c(d.load);  
          return c(d.load); 
        })
        .attr("x1", function(d) { return data.nodes[d.from].x; })
        .attr("y1", function(d) { return -1 * data.nodes[d.from].y; })
        .attr("x2", function(d) { return data.nodes[d.to].x;})
        .attr("y2", function(d) { return -1 * data.nodes[d.to].y; })
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
       .data(data.nodes)
          .attr("r", function(d) {
            return d.r = d.capacity * 10 + 3;
          })
          .style("fill", function(d) { return c(d.capacity); })
     .enter().append("svg:circle")
       .attr("class", "node")
       .attr("x", function(d) { return d.x; })
       .attr("cx", function(d) { return d.x; })
       .attr("cy", function(d) { return -1 * d.y; })
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
      if (opts.x) {
        // the next two lines do the same, but only one works 
        // in the specific context
        vis.attr("x", opts.x);
        vis.style("margin-left", opts.x + "px"); 
      }
      if (opts.y) {
        vis.attr("y", opts.y);
        vis.style("margin-top", opts.y + "px"); 
      }
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