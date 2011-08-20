

function OML_map(opts) {
  this.data = null;
  
  /* Restrict minimum and maximum zoom levels. */
  [G_NORMAL_MAP, G_HYBRID_MAP, G_PHYSICAL_MAP].forEach(function(t){
    t.getMinimumResolution = function(){
      return 4
    };
    t.getMaximumResolution = function(){
      return 8
    };
  });
}
OML_map.prototype = pv.extend(GOverlay);

OML_map.prototype.init = function(data) {
  
  this.data = data;
  /* Create the map, embedding our visualization! */
  var graph = document.getElementById("graph");
  graph.style.width = 800 + "px";
  graph.style.height = 600 + "px";
  var map = new GMap2(graph);

  
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
  
  var zoom = 18;
  map.setCenter(new GLatLng((lat_max + lat_min) / 2, (lon_max + lon_min) / 2), zoom);
    
  var ui = map.getDefaultUI();
  ui.maptypes.satellite = false;
  map.setUI(ui);
  map.setMapType(G_PHYSICAL_MAP);
  map.addOverlay(this);
}


/* Add our canvas to the map pane when initialized. */
OML_map.prototype.initialize = function(map) {
  this.map = map;
  this.canvas = document.createElement("div");
  this.canvas.setAttribute("class", "canvas");
  map.getPane(G_MAP_MAP_PANE).parentNode.appendChild(this.canvas);
};

 /* Redraw the visualizations when the map is moved. */
OML_map.prototype.redraw = function(force) {
  
  return;
  
  /* Only update lines when the map is zoomed. */
  if (!force) return;

  var data = this.data;
  if (data == null) return;
  
  var m = this.map;
  var c = this.canvas;

  /* Convert latitude and longitude to pixel locations. */
  var paths = data.map(function(l) {
            return l.values.map(function(s) {
              var p = m.fromLatLngToDivPixel(new GLatLng(s[1], s[2]));
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

  /* Troop count visualization. */
  var panel = new pv.Panel()
      .canvas(c)
      .data(paths)
/*
    .add(pv.Panel)
      .data(function(d) {return d.values})
*/

   panel.add(pv.Line)
    .segmented(true)
/*
   panel.add(pv.Dot)
    .data(function(d) {return d.values})
*/
    .data(function(d) {return d})
    .left(function(d) {return d.x - x.min + r})
      .top(function(d) {return d.y - y.min + r})
     .lineWidth(5)
/*
    .lineWidth(function(d) {return Math.max(1, k * d.size)})
*/
     .strokeStyle(pv.colors("black", "red").by(function(d) {return d.dir}))
      .title(function(d) {return d.size})


/* Current index line. */
panel.add(pv.Rule)
/* .visible(function() {return idx >= 0 && idx != vis.i()}) 
    .left(function() {return x(idx)})
*/
    .left(100)
    .top(-4)
    .bottom(-4)
    .strokeStyle("red")
/*
  .anchor("bottom").add(pv.Label)
.text(function() {return stocks.Date.values[idx]});
*/

    .root.render();
};

