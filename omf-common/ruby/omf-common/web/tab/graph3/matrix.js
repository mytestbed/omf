
var color = pv.Colors.category19().by(function(d) {
  return d.group
});

var color2 = pv.Scale.linear(0, 20).range("green", "red").by(function(l) {
      return l.linkValue;
});

var vis = new pv.Panel()
    .width(700)
    .height(700)
    .top(90)
    .left(90);

var layout = vis.add(pv.Layout.Matrix)
    .nodes(oml_data.nodes)
    .links(oml_data.links)
    .directed(true);
//    .nodes(miserables.nodes)
//    .links(miserables.links)
//    .sort(function(a, b) {return b.group - a.group});

layout.link.add(pv.Bar)
    .fillStyle(function(l) { 
      return l.linkValue ? color2(l) : '#eee'
    });

layout.label.add(pv.Label)
    .font("bold 15px Arial");
//    .textStyle(color);

vis.render();