

function OML_map2(opts) {
  this.opts = opts;
  this.data = null;
  
  /* Restrict minimum and maximum zoom levels.
  [G_NORMAL_MAP, G_HYBRID_MAP, G_PHYSICAL_MAP].forEach(function(t){
    t.getMinimumResolution = function(){
      return 4
    };
    t.getMaximumResolution = function(){
      return 8
    };
  });
   */
}

OML_map2.prototype = pv.extend(google.maps.OverlayView);

OML_map2.prototype.init = function(data) {
  this.data = data;

  var graph = document.getElementById("graph");
  graph.style.width = (this.opts['width'] || 800) + "px";
  graph.style.height = (this.opts['height'] || 600) + "px";

  var center = this.getCenterCoord(data);
  var myOptions = {
    zoom: (this.opts['zoom'] || 17),
    center: center,
    mapTypeId: google.maps.MapTypeId.ROADMAP
  };
  this.map = new google.maps.Map(graph, myOptions);
  this.setMap(this.map);  
}

OML_map2.prototype.update = function(new_data) {
  var do_render = false;
  for (var i = 0; i < new_data.length; i++) {
    var incoming = new_data[i];
    var id = incoming['id'];
    var current = this.data[id];
    if (current != undefined) {
      /* can't handle any new series half-way through */
      var val = incoming['values'];
      if (val != undefined && val.length > 0) {
        current['values'] = current['values'].concat(incoming['values']);
        do_render = true;          
      }
    }
  }
  if (do_render) {
    this.draw();
  }
}

OML_map2.prototype.getCenterCoord = function (data) {
  /* center graph initially */
  var lat_min = 1000;
  var lat_max = -1000;
  var lon_min = 1000;
  var lon_max = -1000;
  data.each(function(l) {
              l.values.each(function(s) {
                var lat = s[1];
                if (lat > lat_max) lat_max = lat;
                if (lat < lat_min) lat_min = lat;
                var lon = s[2];
                if (lon > lon_max) lon_max = lon;
                if (lon < lon_min) lon_min = lon;
              });
            });
  
  var middle = new google.maps.LatLng((lat_max + lat_min) / 2, (lon_max + lon_min) / 2);
  return middle;
}

OML_map2.prototype.onAdd = function() {

  // Note: an overlay's receipt of onAdd() indicates that
  // the map's panes are now available for attaching
  // the overlay to the map via the DOM.

  var canvas = this.canvas = document.createElement('map_overlay');
  canvas.style.border = "none";
  canvas.style.borderWidth = "0px";
  canvas.style.position = "absolute";
  /*
  canvas.style.width = 800 + "px";
  canvas.style.height = 600 + "px";
  canvas.style.left = 0 + "px";
  canvas.style.top = 0 + "px";
  */
 
  // We add an overlay to a map via one of the map's panes.
  // We'll add this overlay to the overlayImage pane.
  var panes = this.getPanes();
  panes.overlayLayer.appendChild(canvas);
  
  /* this.panel = new pv.Panel().canvas(canvas); */ 
}

 /* Redraw the visualizations when the map is moved. */
OML_map2.prototype.draw = function() {
  
  var data = this.data;
  if (data == null) return;
  
  var m = this.map;
  var c = this.canvas;

  /* Convert latitude and longitude to pixel locations. */
  var projection = this.getProjection();
  var paths = data.map(function(l) {
            return l.values.map(function(s) {
              var loc = new google.maps.LatLng(s[1], s[2]);
              var p = projection.fromLatLngToDivPixel(loc);
              return p;
            });
          });

  function x(p) {return p.x};
  function y(p) {return p.y};
  var x = {
    min: pv.min(paths.map(function(l) {return pv.min(l, x)})),
    max: pv.min(paths.map(function(l) {return pv.max(l, x)}))
  };
  var y = {
    min: pv.min(paths.map(function(l) {return pv.min(l, y)})),
    max: pv.min(paths.map(function(l) {return pv.max(l, y)}))
  };
  var k = (y.max - y.min) / 1000000;

  /* Update the canvas bounds. Note: may be large. */
  var r = 50;
  var w = pv.max([x.max - x.min + 2 * r, 300]);
  var h = pv.max([y.max - y.min + 2 * r, 300]);
  
  c.style.width = w + "px";
  c.style.height = h + "px";
  c.style.left = x.min - r + "px";
  c.style.top = y.min - r + "px";

  var panel = new pv.Panel()
      .canvas(c)
      .data(paths)
      .add(pv.Line)
        .segmented(true)
        .data(function(d) {return d})
        .left(function(d) {return d.x - x.min + r})
        .top(function(d) {return d.y - y.min + r})
        .lineWidth(5)


/* Current index line. */
/*
panel.add(pv.Rule)
*/

/* .visible(function() {return idx >= 0 && idx != vis.i()}) 
    .left(function() {return x(idx)})
*/
/*
    .left(100)
    .top(-4)
    .bottom(-4)
    .strokeStyle("red")
*/
/*
  .anchor("bottom").add(pv.Label)
.text(function() {return stocks.Date.values[idx]});
*/

    .root.render();
};

