require_obj('pv', {url: ['protovis-d3.2']}, function() { 

  OML_line_chart2 = function(opts) { 

    var fx = this.fy = function(d) {return d[1]}; // y-axis value
    var fy = this.fx = function(d) {return d[0]};  // x-axis value
    this.canvas = opts['canvas'] || 'graph';
    this.w = opts["width"] || 730;
    this.h = opts["height"] || 360;
    this.legendWidth = 200;
    this.leftBorder = 0;

    this.graphWidth = this.w - this.legendWidth;
	  this.opts = opts;
    this.data = [];

    this.init = function(data) {
      this.data = data;
      var vis = this.vis;

      this.shadowPanel = vis.add(pv.Panel);
      this.linePanel = vis.add(pv.Panel);

      /* The legend panel. */
      var legend = graph.add(pv.Panel).left(this.graphWidth).width(this.legendWidth);

      legend.add(pv.Dot).data(data).left(30).top(function(){
	  return this.index * 25 + 20
      }).size(12).strokeStyle(null).fillStyle(function(){
	  return color(this.index);
      }).anchor("right").add(pv.Label).font("12pt Arial").text(function(d){
	  return d.label;
      });


      /* Current index line.  
      var idx = null;
      vis.add(pv.Rule).visible(function(){
	  return idx >= 0 && idx != vis.i()
      }).left(function(){
	  return x(idx)
      }).top(0).bottom(0).strokeStyle("red").anchor("right").add(pv.Label).top(h - 50).text(function(){
	  return idx 
      });
       */
      this.render();
    }

    this.update = function(new_data) {
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

    this.render = function() {
      var data = this.data;

      /* calculate range of X axis */
      var xmin = this.opts["xMin"];
      var fx = this.fx;
      if (xmin == undefined) {
	  xmin = pv.min(data.map(function(d){
	      return pv.min(d.values, fx)
	  }));
      }
      var xmax = pv.max(data.map(function(d){
	  return pv.max(d.values, fx)
      }));
      this.x.domain(xmin, xmax).nice();

      /* calculate range of Y axis */
      var ymin = this.opts["yMin"]
      var fy = this.fy;
      if (ymin == undefined) {
	  ymin = pv.min(data.map(function(d){
	      return pv.min(d.values, fy)
	  }));
      }
      var ymax = pv.max(data.map(function(d){
	  return pv.max(d.values, fy)
      }));
      this.y.domain(ymin, ymax).nice();

      var vis = this.vis;

      /* shadow */
      this.shadowPanel.data(data).add(pv.Line).data(function(d){
	  return d.values
      }).left(function(d){
	  return x(fx(d)) + 2
      }).bottom(function(d){
	  return y(fy(d)) - 2
      }).strokeStyle("#cccccc").lineWidth(2);

      /* lines.*/
      this.linePanel.data(data).add(pv.Line).data(function(d){
	  return d.values
      }).left(x.by(fx)).bottom(y.by(fy)).lineWidth(2)
      /*
       .add(pv.Dot).visible(function(d){
	  var index = this.index;
	  var selected = vis.i();
	  var x = idx;
	  return fx(d) == idx
      })
      */

      this.graph.render();
    }

    /* this.initGraph = function() { */

    var graph = this.graph = new pv.Panel()
         .canvas(this.canvas)
         .left(60)
         .right(70)
         .top(20)
         .width(this.w)
         .height(this.h); 
      var data = this.data;
      var w = this.w;
      var h = this.h;
      var color = pv.Colors.category10();
      var x = this.x = pv.Scale.linear(0, 5).range(0, this.graphWidth);
      var y = this.y = pv.Scale.linear(0, 5).range(0, h);

      var vis = this.vis = graph.add(pv.Panel).def("i", -1).bottom(40).width(this.graphWidth);

      /* Y-axis */
      vis.add(pv.Rule).data(function(){
	  return y.ticks()
      }).bottom(y).strokeStyle("#cccccc").anchor("left").add(pv.Label).text(function(v) {
	  return v.toPrecision(2);
      });
      /* .text(y.tickFormat(2)); */
      /* toPrecision(2) */


      /* Y-axis label */
      var yLabel = this.opts["yLabel"];
      if (yLabel) {
	  vis.add(pv.Label).data([yLabel]).left(-45).bottom(h / 2).font("10pt Arial").textAlign("center").textAngle(-Math.PI / 2);
      }

      /* X-axis ticks. */
      vis.add(pv.Rule).data(function(){
	  return x.ticks()
      }).left(x).strokeStyle("#eee").anchor("bottom").add(pv.Label).text(function(v){
	  return v.toPrecision(2);
      }) /* .text(x.tickFormat) */.visible(function(){
	  return this.index > 0
      }); /* skip the tick at the origin */
      /* X-axis label */
      var xLabel = this.opts["xLabel"];
      if (xLabel) {
	  vis.add(pv.Label).data([xLabel]).bottom(-35).left(this.graphWidth / 2).font("10pt Arial").textAlign("center")
      }



      /* An invisible bar to capture events (without flickering).   
      vis.add(pv.Panel).events("all").event("mousemove", function(){
	  idx = x.invert(vis.mouse().x) >> 0;
	  var p = pv.Behavior.point(Infinity);
	  vis.render();
      });
      */

      graph.render();

  }
});
