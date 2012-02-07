
var color = pv.Scale.linear(0, 100).range("green", "red").by(function(l) {
              return l.linkValue;
            });

var vis = new pv.Panel()
    .width(400)
    .height(400)
    .top(40)
    .left(40);

var layout = vis.add(pv.Layout.Matrix)
    .nodes(oml_data.nodes)
    .links(oml_data.links)
    .directed(true);

layout.link.add(pv.Bar)
    .fillStyle(function(l) { 
      return l.linkValue ? color(l) : '#eee'
    });

layout.label.add(pv.Label)
    .font("bold 15px Arial");
//    .textStyle(color);

vis.render();
