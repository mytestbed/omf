L.provide('OML.demo_topo', [["raphael/raphael.js", "raphael/raphael.arrow-set.js"]], function () {

  OML['demo_topo'] = Backbone.Model.extend({

    draw: function(p) {
      this.server(100, 50, 'EC2', 'Sender1\nec2-23-20-77-153');
      this.server(300, 125, 'PL', 'Receiver\nplanetlab4.rutgers.edu');      
      this.server(100, 200, 'ORCA', 'Sender2\nduke.edu');      


      this.arrow(100, 50, 300, 125);
      this.arrow(100, 200, 300, 125);      
    },
    
    server: function(x, y, cf, name) {
      var p = this.paper;
      var r = this.r;
      p.circle(x, y, r).attr({fill: 'white'});
      p.text(x, y, cf).attr({"font-size": '16'});      
      p.text(x, y + r + 16, name);
    },
    
    arrow: function(x1, y1, x2, y2) {
      var dx = x1 - x2;
      var dy = y1 - y2;
      var l = Math.sqrt(dx * dx + dy * dy);
      var f = this.r / l;
      
      var a = this.paper.arrowSet((x1 - dx * f), (y1 - dy * f), (x2 - 20 + dx * f), (y2 + dy * f), 10);
      a[0].attr({"stroke-width" : "1", stroke: "#aaa", fill: "#aaa" });
      a[1].attr({"stroke-width" : "6", stroke: "#aaa" });
      //a[1].attr({"stroke-width" : "6", stroke: "green" });
    },
    

    initialize: function(opts) {
      this.opts = opts;
      var o = this.opts;

      var w = this.w = o['width'] || 600;
      var h = this.h = o['height'] || 400;
      var r = this.r = o['server-radius'] || 30;
      
      var el = $(o.base_el)[0];
      var p = this.paper = Raphael(el, w, h);
      this.draw(p)
    }
    
  })

})