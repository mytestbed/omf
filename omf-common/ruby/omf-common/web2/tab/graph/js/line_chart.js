

function oml_line_chart(data, opts) { 

  var fy = function(d) {return d[1]}, // y-axis value
      fx = function(d) {return d[0]},  // x-axis value
      w = opts["width"] || 730,
      h = opts["height"] || 360,
      rightBorder = w,
      leftBorder = 0

  var color = pv.Colors.category10();

  /* calculate range of X axis */
  var x = pv.Scale.linear(0, 5).range(0, w);
  var xmin = opts["xMin"]
  if (xmin == undefined) {
    xmin = pv.min(data.map(function(d) {return pv.min(d.values, fx)}));
  }
  var xmax = pv.max(data.map(function(d) {return pv.max(d.values, fx)}));
  x.domain(xmin, xmax).nice();

  /* calculate range of Y axis */
  var y = pv.Scale.linear(0, 5).range(0, h);
  var ymin = opts["yMin"]
  if (ymin == undefined) {
    ymin = pv.min(data.map(function(d) {return pv.min(d.values, fy)}));
  }
  var ymax = pv.max(data.map(function(d) {return pv.max(d.values, fy)}));
  y.domain(ymin, ymax).nice();

  /* The visualization panel. Stores the active index. */
  var vis = new pv.Panel()
      .def("i", -1)
      .left(60)
      .right(70)
      .top(20.5)
      .bottom(40)
      .width(w)
      .height(h);

  /* Y-axis */
  vis.add(pv.Rule)
      .data(function() {return y.ticks()})
      .bottom(y)
      .strokeStyle("#cccccc")
    .anchor("left").add(pv.Label)
      .text(function(v) {return v.toPrecision(2);});
      /* .text(y.tickFormat(2)); */  /* toPrecision(2) */


  /* Y-axis label */
  var yLabel = opts["yLabel"];
  if (yLabel) {
    vis.add(pv.Label)
			.data([yLabel])
			.left(-45)
			.bottom(h/2)
			.font("10pt Arial")
			.textAlign("center")
			.textAngle(-Math.PI/2);
  }

  /* X-axis ticks. */
  vis.add(pv.Rule)
      .data(function() {return x.ticks()})
      .left(x)
      .strokeStyle("#eee")
    .anchor("bottom").add(pv.Label)
		  .text(function(v) {return v.toPrecision(2);})
      /* .text(x.tickFormat) */
			.visible(function() {return this.index > 0}); /* skip the tick at the origin */

  /* X-axis label */
  var xLabel = opts["xLabel"];
  if (xLabel) {
    vis.add(pv.Label)
			.data([xLabel])
			.bottom(-35)
			.left(w/2)
			.font("10pt Arial")
			.textAlign("center")
  }


  /* lines. */
  vis.add(pv.Panel)
      .data(function() {return data})
    .add(pv.Line)
      .data(function(d) {return d.values})
      .left(x.by(fx))
      .bottom(y.by(fy))
      .lineWidth(2)

  /* legend */
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

  vis.render();
}
