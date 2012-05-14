L.provide('OML.network', ["/resource/vendor/d3/d3.js"], function () {

  OML['network'] = function(opts) { 
    this.opts = opts || {};
    this.data = null;
    
    this.decl_properties = {
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
    };
    
    this.decl_color_func = {
      "green_yellow80_red": d3.scale.linear()
                              .domain([0, 0.8, 1])
                              .range(["green", "yellow", "red"]),
      "green_red":          d3.scale.linear()
                              .domain([0, 1])
                              .range(["green", "red"])
    };
    
    
    this.init = function() {
      var o = this.opts;
      var self = this;
  
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
      
      var self = this;
      OHUB.bind("graph.highlighted", function(evt) {
        if (evt.source == self) return;
        self.on_highlighted(evt);
      });
      
      var schemas = this.schemas = {};
      _.map(o.schema, function(sa, name) {
        var schema = schemas[name] = {};
        _.map(sa, function(s, i) {
          s['index'] = i;
          schema[s.name] = s;
        })
      });
      
      var mapping = this.mapping = {};
      _.map(['nodes', 'links'], function(n) {
        var schema = schemas[n];
        // var schema = {};
        // _.map(o.schema[n], function(se, i) {
          // se['index'] = i;
          // schema[se.name] = se;
        // });
        var m = mapping[n] = {};
        var om = o.mapping[n] || {};      
        _.map(self.decl_properties[n], function(a) {
          var pname = a[0]; var type = a[1]; var def = a[2];
          var descr = om[pname];
          // if (descr != undefined) {
            // if (descr['stream'] == undefined) descr['stream'] = n;
          // }
          m[pname] = self.create_mapping(pname, descr, n, type, def)
        });
      });
      
      var data = o.data;
      if (data) this.update(data);

    };
  
    this.append = function(a_data) {
      throw "DOESN'T WORK";
      
      var data = this.data;
      data.nodes = $.extend(data.nodes, a_data.nodes);
      data.links = $.extend(data.links, a_data.links);      
      this.redraw();   
    };

    this.update = function(sources) {
      if (! (sources instanceof Array)) {
        throw "Expected an array"
      }
      if (sources.length != 1) {
        throw "Can only process a SINGLE source"
      }
      var data_source = OML.data_sources[sources[0].stream];
      if ((this.data = data_source.events) == null) {
        throw "Missing events array in data source"
      }
      
      
      var data = this.data = {};
      _.each(sources, function(s) {
        data[s.stream] = s.events;
      });
      
      // clear indexed tables
      this.indexed_tables = {};

      this.redraw();
    };
    
    this.redraw = function() {
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
      // var c = d3.scale.linear()
          // .domain([0, 0.8, 1])
          // .range(["green", "yellow", "red"]);
//       
      // this._func = {};
      // var lmapping = mapping.link; 
      // var lstroke = c(0);
      // var lstroke_width = 4;
      // if (typeof(lmapping) != "undefined") {
        // lstroke_width = this.property_mapper('stroke_width', lmapping.stroke_width, lstroke_width);
        // lstroke = this.property_mapper('stroke', lmapping.stroke_color, lstroke);
      // } 
      // this._func.lstroke = lstroke;
      // this._func.lstroke_width = lstroke_width;
//         
      // var nmapping = mapping.node; 
      // var nfill = "white";
      // var nradius = 10;
      // if (typeof(nmapping) != "undefined") {
        // nfill = this.property_mapper('fill', nmapping.fill_color, nfill);
        // nradius = this.property_mapper('radius', nmapping.radius, nradius);
      // } 
      // this._func.nfill = nfill;
      // this._func.nradius = nradius;
      
          
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
          
      var lmapping = mapping.links;
      var nmapping = mapping.nodes;

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

        var l = d3.svg.line().interpolate('basis');
        return l([[x1, y1], [x2, y2], [x3, y3]]);
      };

      var link2 = vis.selectAll("path.link")
        .data(d3.values(data.links))
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
         .attr("cx", function(d) { return x(nmapping.x(d)) }) 
         .attr("cy", function(d) { return y(nmapping.y(d)) })
         .attr("r", nmapping.radius)
         .style("fill", nmapping.fill_color)
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
      var names = _.map(nodes, function(el) { return el.id});
      var vis = this.base_layer;
      var key_f = this.mapping.nodes.key;
      vis.selectAll("circle.node")
       .filter(function(d) {
         var key = key_f(d);
         return ! _.include(names, key);
       })
       .transition()
         .style("stroke", "lightgray")
         .style("fill", "rgb(240,240,240)")               
         .delay(0)
         .duration(300);
    }
    
    
    this._on_nodes_dehighlighted = function() {
      var vis = this.base_layer;
      var nmapping = this.mapping.nodes;
      vis.selectAll("circle.node")
       .transition()
         .style("fill", nmapping.fill_color)
         .style("stroke", nmapping.stroke_color)
         .delay(0)
         .duration(300);   
    }

    this._on_links_highlighted = function(links) {
      var names = _.map(links, function(el) { return el.id});
      var vis = this.base_layer;
      var key_f = this.mapping.links.key;
      vis.selectAll("path.link")
       .filter(function(d) {
         var key = key_f(d);
         return ! _.include(names, key);
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

    // this.property_mapper = function(name, sm, def_value) {
      // var mapper_f;
      // if (typeof(sm) != "undefined") {
        // var prop = sm.property;
        // var scale = sm.scale ? sm.scale : 1;
        // var color_f = sm.color ? this.color_func[sm.color] : null;
        // var max = sm.max ? sm.max : 10;
        // var min = sm.min ? sm.min : 1;
        // if (color_f == null) {
          // mapper_f = function(d) {
            // var v = d[prop] * scale;
            // var t = typeof(v);
            // if (v > max) { 
              // v = max; 
            // } else if (v < min) { 
              // v = min; 
            // } else if (isNaN(v)) {
              // v = max;
            // }
            // d[name] = v;
            // return v;
          // }
        // } else {
          // mapper_f = function(d) {
            // var v = d[prop] * scale;
            // if (v > 1.0) { 
              // v = 1.0; 
            // } else if (v < 0) { 
              // v = 0; 
            // } else if (isNaN(v)) {
              // v = 0;
            // }
            // v = color_f(v);
            // d[name] = v;
            // return v;
          // }
        // }
      // } else {
        // mapper_f = def_value;
      // }
      // return mapper_f;
    // }
    
            // :radius => {:property => :capacity, :scale => 20, :min => 4},
        // :fill_color => {:property => :capacity, :color => :green_yellow80_red}
      // },
      // :link => {
        // :stroke_width => {:property => :store_forward, :scale => 5, :min => 3},
        // :stroke_color => {:property => :store_forward, :scale => 1.0 / 1.3, :color => :green_yellow80_red}

   this.create_mapping = function(mname, descr, stream, type, def) {
     var self = this;
     if (descr == undefined && typeof(def) == 'object') {
       descr = def
     }
     if (descr == undefined) {
       if (type == 'index') {
         return this.create_mapping(mname, def, stream, type, null);
       } else {
        return function(d) { 
          return def; 
        }
       }
     }
     if (descr.stream != undefined) {
       stream = descr.stream;  // override stream
     }
     var schema = this.schema_for_stream(stream);
     if (schema == undefined) {
       throw "Can't find schema for stream '" + stream + "'.";
     }
     
     if (type == 'index') {
       var key = descr.key;
       if (key == undefined || stream == undefined) {
         throw "Missing 'key' or 'stream' in mapping declaration for '" + mname + "'.";
       }
       var col_schema = schema[key];
       if (col_schema == undefined) {
         throw "Unknown stream element '" + key + "'.";
       }
       var vindex = col_schema.index;
       
       var jstream = descr.join_stream;
       if (jstream == undefined) {
         throw "Missing join stream declaration in '" + mname + "'.";
       }
       var jschema = this.schema_for_stream(jstream);
       if (jschema == undefined) {
         throw "Can't find schema for stream '" + jstream + "'.";
       }

       var jkey = descr.join_key;
       if (jkey == undefined) jkey = 'id';
       var jcol_schema = jschema[jkey];       
       if (jcol_schema == undefined) {
         throw "Unknown stream element '" + jkey + "' in '" + jstream + "'.";
       }
       var jindex = jcol_schema.index;
       
       return function(d) {
         var join = d[vindex];
         var t = self.get_indexed_table(jstream, jindex);
         var r = t[join];
         return r;
       }
     } else {
       var pname = descr.property;
       var col_schema = schema[pname];
       if (col_schema == undefined) {
         throw "Unknown property '" + pname + "'.";
       }
       var index = col_schema.index;
       switch (type) {
       case 'int': 
         var scale = descr.scale;
         var min_value = descr.min;
         var max_value = descr.max;
         return function(d) {
           var v = d[index];
           if (scale != undefined) v = v * scale; 
           if (min_value != undefined && v < min_value) v = min_value; 
           if (max_value != undefined && v > max_value) v = max_value; 
           return v;
         };
       case 'color': 
         var color_fname = descr.color;
         if (color_fname == undefined) {
           throw "Missing color function for '" + mname + "'.";
         } 
         var color_f = self.decl_color_func[color_fname];
         if (color_f == undefined) {
           throw "Unknown color function '" + color_fname + "'.";
         } 
         var scale = descr.scale;
         var min_value = descr.min;
         return function(d) {
           var v = d[index];
           if (scale != undefined) v = v * scale; 
           if (min_value != undefined && v < min_value) v = min_value; 
           var color = color_f(v);
           return color;
         };
       case 'key' :
         return function(d) {
           return d[index];
         }
       default:    
         throw "Unknown mapping type '" + type + "'";
       }
     }
     var i = 0;
   };
    
   /*
    * This returns a table held in +data+ as a hash with the key taken 
    * from the respective row at +index+.
    * 
    * NOTE: This is a bit hack right now. We should really rap the sources/tables
    * into their own object.
    */
   this.get_indexed_table = function(stream, index) {
     var itbl_name = stream + index;
     var t = this.indexed_tables[itbl_name];
     if (t == undefined) {
       // build it
       var t = this.indexed_tables[itbl_name] = {};
       var st = this.data[stream];
       if (st == undefined) {
         throw "Unknown stream '" + stream + "'.";
       }
       _.each(st, function(r) {
         var idx = r[index]
         t[idx] = r;
       })  
     }
     return t;
   }
   
   /*
    * Return schema for +stream+.
    */
   this.schema_for_stream = function(stream) {
     return this.schemas[stream];
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