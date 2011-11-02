L.provide('OML.network', ["d3/d3"], function () {

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
  
      this.color_func = {
        "green_yellow80_red": d3.scale.linear()
                                .domain([0, 0.8, 1])
                                .range(["green", "yellow", "red"]),
        "green_red":          d3.scale.linear()
                                .domain([0, 1])
                                .range(["green", "red"])
      };
      this.graph_layer = g.append("svg:g");
      
      var self = this;
      OHUB.bind("graph.highlighted", function(evt) {
        if (evt.source == self) return;
        self.on_highlighted(evt);
      });
      
      var data = this.data = o.data;
      if (data) this.redraw({});
    };
  
    this.append = function(a_data) {
      var data = this.data;
      data.nodes = $.extend(data.nodes, a_data.nodes);
      data.links = $.extend(data.links, a_data.links);      
      this.redraw({});   
    };

    this.update = function(data) {
      this.data = data;
      this.redraw({});
    };
    
    this.redraw = function(ropts) {
      var self = this;
      var data = this.data;
      var o = this.opts;
      var mapping = o.mapping || {};
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
      
      this._func = {};
      var lmapping = mapping.link; 
      var lstroke = c(0);
      var lstroke_width = 4;
      if (typeof(lmapping) != "undefined") {
        lstroke_width = this.property_mapper('stroke_width', lmapping.stroke_width, lstroke_width);
        lstroke = this.property_mapper('stroke', lmapping.stroke_color, lstroke);
      } 
      this._func.lstroke = lstroke;
      this._func.lstroke_width = lstroke_width;
        
      var nmapping = mapping.node; 
      var nfill = "white";
      var nradius = 10;
      if (typeof(nmapping) != "undefined") {
        nfill = this.property_mapper('fill', nmapping.fill_color, nfill);
        nradius = this.property_mapper('radius', nmapping.radius, nradius);
      } 
      this._func.nfill = nfill;
      this._func.nradius = nradius;
      
          
      var vis = this.base_layer;
      // var link = vis.selectAll("line.link")
        // .data(d3.values(data.links))
          // .style("stroke", lstroke)
          // .style("stroke-width", lstroke_width)
          // .attr("x1", function(d) { 
            // var x1 = x(data.nodes[d.from]);
            // return x(data.nodes[d.from]); 
          // })
          // .attr("y1", function(d) { return y(data.nodes[d.from]); })
          // .attr("x2", function(d) { return x(data.nodes[d.to]); })
          // .attr("y2", function(d) { return y(data.nodes[d.to]); })
        // .enter().append("svg:line")
          // .attr("class", "link")
          // .style("stroke", lstroke)
          // .style("stroke-width", lstroke_width)
          // .attr("x1", function(d) { 
            // var x1 = x(data.nodes[d.from]);
            // return x(data.nodes[d.from]); 
          // })
          // .attr("y1", function(d) { return y(data.nodes[d.from]); })
          // .attr("x2", function(d) { return x(data.nodes[d.to]); })
          // .attr("y2", function(d) { return y(data.nodes[d.to]); })
          // .on("mouseover", function(data) {
            // var name = data.name;
            // self.on_highlighted({'elements': [{'name': name, 'type': 'link'}]});
          // })
          // .on("mouseout", function() {
            // self.on_dehighlighted({});
          // }) 
          
      var line_f = function(d) {
        var a = 0.2;
        var b = 0.3;
        var o = 30;
                      
        var x1 = x(data.nodes[d.from]); 
        var y1 = y(data.nodes[d.from]);
        var x3 = x(data.nodes[d.to]); 
        var y3 = y(data.nodes[d.to]);

        var dx = x3 - x1;
        var dy = y3 - y1;
        var l = Math.sqrt(dx * dx + dy * dy);

        var mx = x1 + a * dx;
        var my = y1 + a * dy;
        var x2 = mx - (dy * o / l)
        var y2 = my + (dx * o / l);              

        var l = d3.svg.line().interpolate('basis');
        return l([[x1, y1], [x2, y2], [x3, y3]]);
      };

      var link2 = vis.selectAll("path.link")
        .data(d3.values(data.links))
          .style("stroke", lstroke)
          .style("stroke-width", lstroke_width)
          .attr("d", line_f)
        .enter().append("svg:path")
          .attr("class", "link")
          .style("stroke", lstroke)
          .style("stroke-width", lstroke_width)
          .attr("fill", "none")         
          .attr("d", line_f)
          .on("mouseover", function(data) {
            var name = data.name;
            self.on_highlighted({'elements': [{'name': name, 'type': 'link'}]});
          })
          .on("mouseout", function() {
            self.on_dehighlighted({});
          }) 
          ;

          
          // .on("mouseover", function() {
            // d3.select(this).transition()
             // .style("stroke-width", function(d) {
               // return d.stroke_width + 3
             // })
            // .delay(0)
            // .duration(300)
          // })
          // .on("mouseout", function() {
            // d3.select(this).transition()
             // .style("stroke-width", function(d) {return d.stroke_width})
             // .delay(0)
             // .duration(300)
          // })
          ;

     var node = vis.selectAll("circle.node")
       .data(d3.values(data.nodes))
         .attr("cx", function(d) { return x(d); })
         .attr("cy", function(d) { return y(d); })
         .attr("r", nradius)
         .style("fill", nfill)
       .enter().append("svg:circle")
         .attr("class", "node")
         .attr("cx", function(d) { return x(d); })
         .attr("cy", function(d) { return y(d); })
         .attr("r", nradius)
         .style("fill", nfill)
         .style("stroke", "gray")
         .style("stroke-width", 1)
         .attr("fixed", true)
         //.call(force.drag)
          .on("mouseover", function(data) {
            var name = data.name;
            self.on_highlighted({'elements': [{'name': name, 'type': 'node'}]});
          })
          .on("mouseout", function() {
            self.on_dehighlighted({});
          })         
        .transition()
          .attr("r", nradius)
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
  
    this.on_highlighted = function(evt) {
      var els = evt.elements;
      var links = _.filter(els, function(el) { return  el.type == 'link'});
      if (links.length > 0) { this._on_links_highlighted(links); }
      var nodes = _.filter(els, function(el) { return  el.type == 'node'});
      if (nodes.length > 0) { this._on_nodes_highlighted(nodes); }

      if (evt.source == null) {
        evt.source = this;
        OHUB.trigger("graph.highlighted", evt);
      }
    }

    this.on_dehighlighted = function(evt) {
      this._on_links_dehighlighted();
      this._on_nodes_dehighlighted();

      if (evt.source == null) {
        evt.source = this;
        OHUB.trigger("graph.dehighlighted", evt);
      }
    }
  
    this._on_nodes_highlighted = function(nodes) {
      var names = _.map(nodes, function(el) { return el.name});
      var vis = this.base_layer;
      vis.selectAll("circle.node")
       .filter(function(d) {
         return ! _.include(names, d.name);
       })
       .transition()
         .style("stroke", "lightgray")
         .style("fill", "rgb(240,240,240)")               
         .delay(0)
         .duration(300);
    }
    
    
    this._on_nodes_dehighlighted = function() {
      var vis = this.base_layer;
      var nfill = this._func.nfill;
      vis.selectAll("circle.node")
       .transition()
         .style("stroke", "gray")
         .style("fill", nfill)
         .delay(0)
         .duration(300);   
    }

    this._on_links_highlighted = function(links) {
      var names = _.map(links, function(el) { return el.name});
      var vis = this.base_layer;
      vis.selectAll("path.link")
       .filter(function(d) {
         return ! _.include(names, d.name);
       })
       .transition()
         .style("opacity", 0.1)
         .delay(0)
         .duration(300);
    }

    this._on_links_dehighlighted = function() {
      var vis = this.base_layer;
      vis.selectAll("path.link")
       .transition()
         .style("opacity", 1.0)         
         .delay(0)
         .duration(300)
    }

    this.property_mapper = function(name, sm, def_value) {
      var mapper_f;
      if (typeof(sm) != "undefined") {
        var prop = sm.property;
        var scale = sm.scale ? sm.scale : 1;
        var color_f = sm.color ? this.color_func[sm.color] : null;
        var max = sm.max ? sm.max : 10;
        var min = sm.min ? sm.min : 1;
        if (color_f == null) {
          mapper_f = function(d) {
            var v = d[prop] * scale;
            var t = typeof(v);
            if (v > max) { 
              v = max; 
            } else if (v < min) { 
              v = min; 
            } else if (isNaN(v)) {
              v = max;
            }
            d[name] = v;
            return v;
          }
        } else {
          mapper_f = function(d) {
            var v = d[prop] * scale;
            if (v > 1.0) { 
              v = 1.0; 
            } else if (v < 0) { 
              v = 0; 
            } else if (isNaN(v)) {
              v = 0;
            }
            v = color_f(v);
            d[name] = v;
            return v;
          }
        }
      } else {
        mapper_f = def_value;
      }
      return mapper_f;
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