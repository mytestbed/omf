var color = pv.Colors.category19().by(function(d){
              return d.group
            });

var vis = new pv.Panel()
    .width(window.innerWidth)
    .height(window.innerHeight)
    .width(400)
    .height(400)
    .fillStyle("white")
		
    .margin(5)
    .fillStyle("#fff")
    .strokeStyle("#ccc")
		
    .event("mousedown", pv.Behavior.pan())
    .event("mousewheel", pv.Behavior.zoom());

var layout = vis.add(pv.Layout.Force)
    .nodes(oml_data.nodes)
    .links(oml_data.links)
    .bound(true)
//    .iterations(1e3)
    .chargeConstant(-400);

layout.link.add(pv.Line)
    .visible(function(from, link) {
      return link.value < 15;
    })
    .lineWidth(function(from, link) {
      return 5 * (30 - link.value) / 30
    })
    ;

layout.node.add(pv.Dot)
    //.size(function(d) {return (d.linkDegree + 4) * Math.pow(this.scale, -1.5)})
    .fillStyle(function(d) {return d.fix ? "brown" : color(d)})
    .strokeStyle(function() {return this.fillStyle().darker()})
    .title(function(d) {return d.nodeName})
    //.size(function(d){return this.scale * 50})
    .size(20)
    //.fillStyle("white")
    .event("mousedown", pv.Behavior.drag())
    .event("drag", layout);

vis.render();
