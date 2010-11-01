
var oml_line_chart_focus_session = {};

function OML_line_chart_focus2(opts){
  this.opts = opts;
  this.data = null;
  
  var w = opts["width"] || 730;
  var h = opts["height"] || 360;
  var h1 = (h - 20) * 0.8;
  var h2 = (h - 20) * 0.2;


  var fy = this.fy = function(d){return d[1]}; // y-axis value
  var fx = this.fx = function(d){return d[0]}; // x-axis value
    
  var rightBorder = w;
  var leftBorder = 0;
  this.i = {x: (w - 100), dx: 100};
  var color = pv.Colors.category10();
      
/*
       function create_scale(data, length, func, min){
        var scale = pv.Scale.linear(0, 5).range(0, length);
        if (min == undefined) {
          min = pv.min(data.map(function(d){
            return pv.min(d.values, func)
          }));
        }
        var max = pv.max(data.map(function(d){
          return pv.max(d.values, func)
        }));
        scale.domain(min, max).nice();
        return scale;
      }
 */     
      
  /* The visualization panel. Stores the active index. */
  var vis = this.vis = new pv.Panel()
    .left(60)
    .right(70)
    .top(20.5)
    .bottom(40)
    .width(w)
    .height(h);
      
  /* Y-axis label */
  var yLabel = opts["yLabel"];
  if (yLabel) {
    vis.add(pv.Label)
      .data([yLabel])
      .left(-45)
      .bottom(h / 2)
      .font("10pt Arial")
      .textAlign("center")
      .textAngle(-Math.PI / 2);
  }
  
  var csx = this.csx = pv.Scale.linear().range(0, w);  /* create_scale(data, w, fx, opts["xMin"]); */
  var csy = this.csy = pv.Scale.linear().range(0, h2);  /* create_scale(data, h2, fy, opts["yMin"]); */
  
  /* Focus panel (zoomed in). */
  
  var fsx = this.fsx = pv.Scale.linear().range(0, w);
  var fsy = this.fsy = pv.Scale.linear().range(0, h1);
  var self = this;
  var focus = this.focus = vis.add(pv.Panel)
    .def("init", function() {
      var data = self.data;
      if (self.data == null) return;
      var i = self.i;
      var d1 = csx.invert(i.x), d2 = csx.invert(i.x + i.dx);
      var dd = self.data.map(function(dl) {
        var da = dl["values"];
        var dd = da.slice(Math.max(0, pv.search.index(da, d1, fx) - 1), pv.search.index(da, d2, fx) + 1);
        return dd;
      });
      fsx.domain(d1, d2).nice();
      
      var ymax = pv.max(dd, function(da){
        return pv.max(da, fy);
      });
      var ymin = opts["yMin"];
      if (!ymin) {
        ymin = pv.min(dd, function(da){
          return pv.min(da, fy);
        });
      }
      fsy.domain(ymin, ymax).nice();
      /*
   fy.domain(scale.checked ? [0, pv.max(dd, function(d) {return d.y})] : y.domain());
   */
      return dd;
    })
    .top(0)
    .height(h1);
  
  
  /* X-axis */
  focus.add(pv.Rule)
    .data(function() {
      return fsx.ticks();
    })
    .left(fsx)
    .strokeStyle("#eee")
    .anchor("bottom")
    .add(pv.Label)
    .text(function(v){
      return v.toPrecision(2);
    })
    .visible(function(){
      /* skip the tick at the origin */
      return this.index > 0
    }); 
    
  /* Y-axis */
  focus.add(pv.Rule)
    .data(function(){
      return fsy.ticks()
    })
    .bottom(fsy)
    .strokeStyle("#cccccc")
    .anchor("left")
    .add(pv.Label)
    .text(function(v){
      return v.toPrecision(2);
    });
    
  /***************  Context panel (zoomed out). */
  var context = this.context = vis.add(pv.Panel)
    .bottom(0)
    .height(h2);
  
  /* X-axis. */
  context.add(pv.Rule)
    .data(function(){
      return csx.ticks()
    })
    .left(csx)
    .strokeStyle("#eee")
    .anchor("bottom")
    .add(pv.Label)
    .text(function(v){
      return v.toPrecision(2);
    })
  /* .text(x.tickFormat) */
  
  /* X-axis label */
  var xLabel = opts["xLabel"];
  if (xLabel) {
    context.add(pv.Label)
      .data([xLabel])
      .bottom(-35)
      .left(w / 2)
      .font("10pt Arial")
      .textAlign("center");
  }
  
    
  vis.render();

}

OML_line_chart_focus2.prototype.init = function(data){
  this.data = data;
  var opts = this.opts;
  /* .text(y.tickFormat(2)); */
  /* toPrecision(2) */
  
  /* The selectable, draggable focus region. */
  this.contextPanel = this.context.add(pv.Panel);
  this.context.add(pv.Panel)
    .data([this.i])
    .cursor("crosshair")
    .events("all")
      .event("mousedown", pv.Behavior.select())
      .event("select", this.focus)
    .add(pv.Bar)
      .left(function(d){
        return d.x
      })
      .width(function(d){
        return d.dx
      })
      .fillStyle("rgba(255, 128, 128, .4)")
      .cursor("move")
        .event("mousedown", pv.Behavior.drag())
        .event("drag", this.focus)
        ;
        
  this.focusPanel = this.focus.add(pv.Panel)
    .overflow("hidden");

  
  /* legend 
   vis.add(pv.Dot)
   .data(data)
   .left(leftBorder + 20)
   .top(function() {return this.index * 25 + 20})
   .size(12)
   .strokeStyle(null)
   .fillStyle(function() {
   return color(this.index);
   })
   .anchor("right").add(pv.Label)
   .font("12pt Arial")
   .text(function(d) {return d.label;});
   */
  /* Current index line.
   vis.add(pv.Rule)
   .visible(function() {return idx >= 0 && idx != vis.i()})
   .left(function() {return x(idx)})
   .top(-4)
   .bottom(-4)
   .strokeStyle("red")
   .anchor("bottom").add(pv.Label)
   .text(function() return {stocks.Date.values[idx]});
   */
  /* An invisible bar to capture events (without flickering). 
   vis.add(pv.Panel)
   .events("all")
   .event("mousemove", function() { idx = x.invert(vis.mouse().x) >> 0; update2(); });
   */
  
  this.render();
}

OML_line_chart_focus2.prototype.render = function() {
  var data = this.data;
      
  /* Focus lines.   */
  var focus = this.focus;  
  var fy = this.fy;
  var fx = this.fx;
  var fsx = this.fsx;
  var fsy = this.fsy;
 
  this.focusPanel
    .data(function(d){
      return focus.init()
    })
    .add(pv.Line)
      .data(function(d){
        return d
      })
      .left(fsx.by(fx))
      .bottom(fsy.by(fy))
      .lineWidth(2);
  
  /*
  focus.add(pv.Dot).data(data).left(leftBorder + 20).top(function(){
    return this.index * 25 + 20
  }).size(12).strokeStyle(null).fillStyle(function(){
    return color(this.index);
  }).anchor("right").add(pv.Label).font("12pt Arial").text(function(d){
    return d.label;
  });
*/
  
  
  /* scale axis */
  var x_min = Infinity;
  var x_max = -Infinity;
  var y_min = Infinity;
  var y_max = -Infinity;
  data.each(function(l) {
              l.values.each(function(s) {
                var x = fx(s);
                if (x > x_max) x_max = x;
                if (x < x_min) x_min = x;
                var y = fy(s);
                if (y > y_max) y_max = y;
                if (y < y_min) y_min = y;
              });
            });
  var csx = this.csx.domain(x_min, x_max).nice();
  var csy = this.csy.domain(y_min, y_max).nice();  
  
  
  /* lines. */
  this.contextPanel
    .data(data)
    .add(pv.Line)
      .data(function(d){
        return d.values
      })
      .left(csx.by(fx))
      .bottom(csy.by(fy))
      .lineWidth(2);
  

  this.vis.render();

}

OML_line_chart_focus2.prototype.update = function(new_data){
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
    this.render();
  }
}




  	

