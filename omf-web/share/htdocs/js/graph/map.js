

L.provide('OML.map', ["d3", "http://maps.google.com/maps/api/js?sensor=true"], function () {
  if (typeof(OML) == "undefined") {
    OML = {};
  }
  
  OML['map'] = function(opts){
    this.opts = opts;

    this.init = function(opts) {
      var base_el = opts.base_el || '#map'
      

      var map = this.map = new google.maps.Map(d3.select(base_el).node(), {
        zoom: 8,
        center: new google.maps.LatLng(37.76487, -122.41948),
        mapTypeId: google.maps.MapTypeId.TERRAIN
      });

// Load the station data. When the data comes back, create an overlay.
//d3.json("stations.json", function(data) {
      
      var data = opts.data;
      if (data) this.update(data);
    };

    this.update = function(data) {
      var overlay = new google.maps.OverlayView();
    
      // Add the container when the overlay is added to the map.
      overlay.onAdd = function() {
        var layer = d3.select(this.getPanes().overlayLayer).append("div")
            .attr("class", "stations");
    
        // Draw each marker as a separate SVG element.
        // We could use a single SVG, but what size would it have?
        overlay.draw = function() {
          var projection = this.getProjection();
    
          var marker = layer.selectAll("svg")
              .data(d3.entries(data))
              .each(transform) // update existing markers
            .enter().append("svg:svg")
              .each(transform)
              .attr("class", "marker");
    
          // Add a circle.
          marker.append("svg:circle")
              .attr("r", 4.5);
    
          // Add a label.
          marker.append("svg:text")
              .attr("x", 7)
              .attr("dy", ".31em")
              .text(function(d) { return d.key; });
    
          function transform(d) {
            d = new google.maps.LatLng(d.value[1], d.value[0]);
            d = projection.fromLatLngToDivPixel(d);
            return d3.select(this)
                .style("left", d.x + "px")
                .style("top", d.y + "px");
          }
        };
      };      
    };
    
    this.init(opts);
  }
});

/*
  Local Variables:
  mode: Javascript
  tab-width: 2
  indent-tabs-mode: nil
  End:
*/