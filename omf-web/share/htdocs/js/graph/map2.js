

//L.provide('OML.map', ["d3", "http://maps.googleapis.com/maps/api/js?sensor=true"], function () {
L.provide('OML.googleLoader', ["http://www.google.com/jsapi"], function () {  
  google.load("maps", "3", {"callback" : onMapLoaded, "other_params":"sensor=true"});
});

function onMapLoaded() {
  
  L.provide('OML.map2', ["graph/abstract_chart", "#OML.abstract_chart"], function () {  
    
    OML.map2 = OML.abstract_chart.extend({
      //this.opts = opts;
      
      decl_properties: [
        ['lat', 'float', {}], 
        ['lng', 'float', {}], 
        ['radius', 'int', 10], 
        ['fill_color', 'color', 'blue'], 
        ['stroke_width', 'int', 1], 
        ['stroke_color', 'color', 'black'], 
      ],
      
      defaults: function() {
        return this.deep_defaults({
          margin: {
            left: 0,
            top:  10,
            right: 20,
            bottom: 0
          },
        }, OML.map2.__super__.defaults.call(this));      
      },    
      
      
      init_svg: function(w, h) {
      //this.init = function(opts) {
        var self = this;
        var opts = this.opts;
        var base_el = opts.base_el || '#map';
        d3.select(base_el)
          .style('position', 'relative')
          .style("height", "100%") 
          .style("width", "100%")
          .style("height", h) 
          .style("width", w)
          ;

        var map_el = this.map_el = base_el.substring(1) + '_map';
        var map_layer = d3.select(base_el).append("div")
                          .attr('id', map_el)
                          ;
        var node = map_layer.node();
        var center = opts.map_center || [151.197189, -33.895508];
        var zoom = opts.zoom;
        if (zoom == undefined) zoom = 17;
        var map = this.map = new google.maps.Map(node, {
          zoom: zoom,
          center: new google.maps.LatLng(center[1], center[0]),
          mapTypeId: google.maps.MapTypeId.ROADMAP
        });
        // force width and height AFTER creating the map, otherwise height is zero.
        var ca = this.widget_area;
        d3.select('#' + map_el)
                          .style("height", ca.h + "px") 
                          .style("width", ca.w + "px")
                          .style("position", "relative")
                          // .style("position", "absolute")
                          .style("top", ca.ty + "px")          
                          .style("left", ca.x + "px")
                          //.style('z-index', '10')        
                          ;

        this.offset = {left: 0, top: 0};
        
        google.maps.event.addListener(map, 'bounds_changed', function() {
          self._resize();
          self.redraw();
        });        
        google.maps.event.addListener(map, 'zoom_changed', function() {
          // some things aren't set yet when 'bounds_changed' is called after a zoom'
          setTimeout(function() {
            self._resize();
            self.redraw();
          }, 100);
        });       
      },
      
      _resize: function() {
        var self = this;
        
        if (self.svg_layer) {
          var map_el = self.map_el;
          var map = $('#' + map_el);
          var div = $('#' + map_el + '_div');            
          var svg = $('#' + map_el + '_svg');
          var map_offset = map.offset();
          var div_offset = div.offset();
          
          svg.width($('#' + map_el).width());
          svg.height($('#' + map_el).height());                        

          //console.log(map_offset.left - div_offset.left);
          // Reposition the SVG layer to cover the entire map area - requires readjustment later (this.offset)
          self.svg_layer
            .style("top", (self.offset.top = map_offset.top - div_offset.top) + "px")       
            .style("left", (self.offset.left = map_offset.left - div_offset.left) + "px")
            ;             
        }   
      },
  
      redraw: function() {
        //console.log("redraw");
        if (this.draw_layer) this._draw(null);
        //this.overlay.map_changed();
      },
      
      _draw: function(overlay) {
        var projection = this.overlay.getProjection();          
        var m = this.mapping;
        var offset = this.offset;
        var x_f = function(d) {
          var lat = m.lat(d.value);
          var lng = m.lng(d.value);
          var point = new google.maps.LatLng(lat, lng);
          var xy = d.xy = projection.fromLatLngToDivPixel(point);
          return xy.x - offset.left;
        };
        var y_f = function(d) {
          return d.xy.y - offset.top;
        };
        var m_f = function(d, m) {
          return (typeof m === "function") ? m(d.value) : m;
        }
        
        var data = d3.entries(this.data_source.events);
        this.draw_layer.selectAll('.marker')
          .data(data)
            .attr("cx", x_f) 
            .attr("cy", y_f)
            .attr("r", function(d) {return m_f(d, m.radius)})
            .style("fill", function(d) {return m_f(d, m.fill_color)})
            .style("stroke", function(d) {return m_f(d, m.stroke_color)})
            .style("stroke-width", function(d) {return m_f(d, m.stroke_width)})
          .enter().append('svg:circle')
            .attr("class", "marker")
            .attr("cx", x_f) 
            .attr("cy", y_f)
            .attr("r", function(d) {return m_f(d, m.radius)})
            .style("fill", function(d) {return m_f(d, m.fill_color)})
            .style("stroke", function(d) {return m_f(d, m.stroke_color)})
            .style("stroke-width", function(d) {return m_f(d, m.stroke_width)})
          ;
      },

      configure_base_layer: function(vis) {
        var overlay = this.overlay = new google.maps.OverlayView();
        var self = this;
        
        // Add the container when the overlay is added to the map.
        overlay.onAdd = function() {
          var overlay_layer = this.getPanes().overlayLayer;
          d3.select(overlay_layer).attr('id', 'fooooo');
          self.div_layer = d3.select(overlay_layer).append("div")
              .attr('id', self.map_el + '_div')
              //.attr('class', this.base_css_class);
              ;          
          self.svg_layer = self.div_layer.append("svg:svg")
              .attr('id', self.map_el + '_svg')
              .style("position", "absolute")
              .style('z-index', '10')                  
              ;
          self.draw_layer = self.svg_layer.append("svg:g")
              ;
          self._resize();
          
          overlay.draw = function() {
            //console.log("overlay draw"); 
            self._draw(this) 
          };
        };      
        overlay.setMap(this.map);
      }
    })
  });

}

/*
  Local Variables:
  mode: Javascript
  tab-width: 2
  indent-tabs-mode: nil
  End:
*/