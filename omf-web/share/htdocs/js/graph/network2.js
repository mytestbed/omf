L.provide('OML.network2', ["graph/abstract_chart", "#OML.abstract_chart", "/resource/vendor/d3/d3.js"], function () {


  
  OML['network2'] = OML.abstract_chart.extend({
    decl_properties: {
      nodes:  [['key', 'key', {property: 'id'}], 
               ['radius', 'int', 30], 
               ['fill_color', 'color', 'blue'], 
               ['stroke_width', 'int', 1], 
               ['stroke_color', 'color', 'black'], 
               ['x', 'int', 10],
               ['y', 'int', 10]
              ],
      links:  [['key', 'key', {property: 'id'}], 
               ['stroke_width', 'int', 2], 
               ['stroke_color', 'color', 'black'],
               ['stroke_fill', 'color', 'blue'],
               ['from', 'index', {key: 'from_id', join_stream: 'nodes', join_key: 'id'}],               
               ['to', 'index', {key: 'to_id', join_stream: 'nodes'}]  // join_key: 'id' ... default
              ]
    },
    
    decl_color_func: {
      "green_yellow80_red": d3.scale.linear()
                              .domain([0, 0.8, 1])
                              .range(["green", "yellow", "red"]),
      "green_red":          d3.scale.linear()
                              .domain([0, 1])
                              .range(["green", "red"])
    },
    
    configure_base_layer: function(vis) {
      var ca = this.chart_area;
      
      this.graph_layer = vis.append("svg:g")
                 .attr("transform", "translate(0, " + ca.h + ")")
                 ;
      this.legend_layer = vis.append("svg:g");
    },
    
    base_css_class: 'oml-network',

    // Find the appropriate data source and bind to it
    //
    init_data_source: function() {
      var o = this.opts;
      var sources = o.data_sources;
      var self = this;
      
      if (! (sources instanceof Array)) {
        throw "Expected an array"
      }
      if (sources.length != 2) {
        throw "Expected TWO data source, one for nodes and one for links"
      }
      var dsh = this.data_source = {};
      _.map(sources, function(s, i) {
        var ds;
        dsh[s.name] = ds = OML.data_sources[sources[i].stream];
        if (o.dynamic == true) {
          ds.on_changed(function(evt) {
            self.redraw();
          });
        }
      });
      if (dsh.links == undefined || dsh.nodes == undefined) {
        throw "Data sources need to be named 'links' and 'nodes'. Missing one or both.";
      }
    },

    process_schema: function() {
      this.schema = {
        nodes: this.process_single_schema(this.data_source.nodes),
        links: this.process_single_schema(this.data_source.links)
      };    
        
      var om = this.opts.mapping;
      if (om.links == undefined || om.nodes == undefined) {
        throw "Missing mapping instructions in 'options' for either 'links' or 'nodes', or both.";
      }
      this.mapping = {
        nodes: this.process_single_mapping('nodes', om.nodes, this.decl_properties.nodes),
        links: this.process_single_mapping('links', om.links, this.decl_properties.links)
      };      
    },
    
    /*
     * Return schema for +stream+.
     */
    schema_for_stream: function(stream) {
      var schema = this.schema[stream];
      return schema;
    },  
    
    data_source_for_stream: function(stream) {
      var ds = this.data_source[stream];
      if (ds == undefined) {
        throw "Unknown data_source '" + stream + "'.";
      }
      return ds;
    },  
    
      
    redraw:  function() {
      var self = this;
      var data = this.data;
      var o = this.opts;
      var mapping = this.mapping; //o.mapping || {};
      var ca = this.chart_area;
      
      var x = function(v) {
        var x = v * ca.w + ca.x;
        return x;
      };
      var y = function(v) {
        var y = -1 * (v * ca.h + ca.y);
        return y;
      };
                
      var vis = this.base_layer;
      var lmapping = mapping.links;
      var nmapping = mapping.nodes;
      var iline_f = d3.svg.line().interpolate('basis');

      // curved line
      var line_f = function(d) {
        var a = 0.2;
        var b = 0.3;
        var o = 30;
        
        var from = lmapping.from(d);
        var to = lmapping.to(d);

        var x1 = x(nmapping.x(from)); 
        var y1 = y(nmapping.y(from));
        var x3 = x(nmapping.x(to)); 
        var y3 = y(nmapping.y(to));

        var dx = x3 - x1;
        var dy = y3 - y1;
        var l = Math.sqrt(dx * dx + dy * dy);

        var mx = x1 + a * dx;
        var my = y1 + a * dy;
        var x2 = mx - (dy * o / l)
        var y2 = my + (dx * o / l);              

        return iline_f([[x1, y1], [x2, y2], [x3, y3]]);
      };

      var ldata = this.data_source.links.events;
      var link2 = this.graph_layer.selectAll("path.link")
        .data(d3.values(ldata))
          //.each(position) // update existing markers
          .style("stroke", lmapping.stroke_color)
          .style("stroke-width", lmapping.stroke_width)
          .attr("d", line_f)
        .enter().append("svg:path")
          .attr("class", "link")
          .style("stroke", lmapping.stroke_color)
          .style("stroke-width", lmapping.stroke_width)
          .attr("fill", "none")         
          .attr("d", line_f)
          .on("mouseover", function(d) {
            var id = lmapping.key(d);
            self.on_highlighted({'elements': [{'id': id, 'type': 'link'}]});
          })
          .on("mouseout", function(d) {
            var id = lmapping.key(d);
            self.on_dehighlighted({'elements': [{'id': id, 'type': 'link'}]});
          }) 
          ;

     var ndata = this.data_source.nodes.events;
     var node = this.graph_layer.selectAll("circle.node")
       .data(d3.values(ndata))
         .attr("cx", function(d) { return x(nmapping.x(d)) }) 
         .attr("cy", function(d) { return y(nmapping.y(d)) })
         .attr("r", nmapping.radius)
         .style("fill", nmapping.fill_color)
         .style("stroke", nmapping.stroke_color)
         .style("stroke-width", nmapping.stroke_width)
       .enter().append("svg:circle")
         .attr("class", "node")
         .attr("cx", function(d) { return x(nmapping.x(d)) }) 
         .attr("cy", function(d) { return y(nmapping.y(d)) })
         .attr("r", nmapping.radius)
         .style("fill", nmapping.fill_color)
         .style("stroke", nmapping.stroke_color)
         .style("stroke-width", nmapping.stroke_width)
         .attr("fixed", true)
         //.call(force.drag)
          .on("mouseover", function(d) {
            var id = nmapping.key(d);
            self.on_highlighted({'elements': [{'id': id, 'type': 'node'}]});
          })
          .on("mouseout", function(d) {
            var id = nmapping.key(d);
            self.on_dehighlighted({'elements': [{'id': id, 'type': 'node'}]});
          })         
        .transition()
          .attr("r", nmapping.radius)
          .delay(0)
       ;      
    },
     
    // this.init_svg = function(w, h) {
      // var opts = this.opts;
// 
      // //if (opts.svg) return opts.svg;
//       
      // var base_el = opts.base_el || "body";
      // if (typeof(base_el) == "string") base_el = d3.select(base_el);
      // var vis = opts.svg = base_el.append("svg:svg")
        // .attr("width", w)
        // .attr("height", h)
        // .attr('class', 'oml-network');
      // return vis;
    // }
  
    on_highlighted: function(evt) {
      var els = evt.elements;
      var links = _.filter(els, function(el) { return  el.type == 'link'});
      if (links.length > 0) { this._on_links_highlighted(links); }
      var nodes = _.filter(els, function(el) { return  el.type == 'node'});
      if (nodes.length > 0) { this._on_nodes_highlighted(nodes); }

      if (evt.source == null) {
        evt.source = this;
        OHUB.trigger("graph.highlighted", evt);
      }
    },

    on_dehighlighted: function(evt) {
      this._on_links_dehighlighted();
      this._on_nodes_dehighlighted();

      if (evt.source == null) {
        evt.source = this;
        OHUB.trigger("graph.dehighlighted", evt);
      }
    },
  
    _on_nodes_highlighted: function(nodes) {
      var names = _.map(nodes, function(el) { return el.id});
      var vis = this.base_layer;
      var key_f = this.mapping.nodes.key;
      this.graph_layer.selectAll("circle.node")
       .filter(function(d) {
         var key = key_f(d);
         return ! _.include(names, key);
       })
       .transition()
         .style("stroke", "lightgray")
         .style("fill", "rgb(240,240,240)")               
         .delay(0)
         .duration(300);
    },
    
    _on_nodes_dehighlighted: function() {
      var vis = this.base_layer;
      var nmapping = this.mapping.nodes;
      this.graph_layer.selectAll("circle.node")
       .transition()
         .style("fill", nmapping.fill_color)
         .style("stroke", nmapping.stroke_color)
         .delay(0)
         .duration(300);   
    },

    _on_links_highlighted: function(links) {
      var names = _.map(links, function(el) { return el.id});
      var vis = this.base_layer;
      var key_f = this.mapping.links.key;
      this.graph_layer.selectAll("path.link")
       .filter(function(d) {
         var key = key_f(d);
         return ! _.include(names, key);
       })
       .transition()
         .style("opacity", 0.1)
         .delay(0)
         .duration(300);
    },

    _on_links_dehighlighted: function() {
      var vis = this.base_layer;
      this.graph_layer.selectAll("path.link")
       .transition()
         .style("opacity", 1.0)         
         .delay(0)
         .duration(300)
    }
   
  })
})

/*
  Local Variables:
  mode: Javascript
  tab-width: 2
  indent-tabs-mode: nil
  End:
*/