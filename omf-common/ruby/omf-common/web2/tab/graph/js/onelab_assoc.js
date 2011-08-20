
require_obj('Raphael.fn.arrowSet', {url: ['raphael_full', 'raphael.arrow-set']}, function() { 


  OML_onelab_assoc = function(opts) {
    this.opts = opts;

    this.middle = 250;

    this.assoc1 = null;
    this.assoc2 = null;
    this.signal1 = null;
    this.signal2 = null;

    this.init = function(data){
      var paper = Raphael("graph", 640, 500);

      var l_scale = 0.4;
      var n_scale = 0.2;

      var ny = 10;
      var ly = 200;

      var middle = this.middle;
      var skip = 50;
      var skip_a = 20;

      var nw = 808 * n_scale;
      var nh = 610 * n_scale;

      var nx1 = middle - skip - nw;
      paper.image("/resource/image/norbit_808_610.gif", nx1, ny, nw, nh);
      var t1 = paper.text(nx1 + nw / 2, ny + 30, "AP1");
      t1.attr({"font-family": "Verdana", "font-size": "25"});

      var nx2 = middle + skip;
      paper.image("/resource/image/norbit_808_610.gif", nx2, ny, nw, nh);
      var t2 = paper.text(nx2 + nw / 2, ny + 30, "AP2");
      t2.attr({"font-family": "Verdana", "font-size": "25"});

      var lw = 310 * l_scale;
      var lx = middle - 0.5 * 310 * l_scale;
      paper.image("/resource/image/laptop_310_256.png", lx, ly, lw, 256 * l_scale);

      assoc1 = paper.arrowSet(middle - 0.5 * lw, ly,  middle - skip - 0.5 * nw, nh + 10, 10);
      this.format_arrow(assoc1, "#F00");

      assoc2 = paper.arrowSet(middle + 0.5 * lw, ly,  middle + skip + 0.5 * nw, nh + 10, 10);
      this.format_arrow(assoc2, "#00F");

      var pw = 50;
      var ph = 20;
      var py = (ly + ny + nh) / 2;
      signal1 = paper.rect(middle - pw, py, pw, ph);
      signal1.attr({ "fill" : "#F00", "stroke-width": 0});
      signal2 = paper.rect(middle, py, pw, ph);
      signal2.attr({ "fill" : "#00F", "stroke-width": 0});
      paper.rect(middle - pw, py, 2 * pw, ph);

      this.update(data);
    }

    this.format_arrow = function(a, fill) {
      a[0].attr({ "fill" : fill, "stroke": fill });
      a[1].attr({ "stroke" : fill, "stroke-width" : "4" });
    }

    this.update = function(data) {
      var p = data[0]['values'][0];
      var assoc = p['associated'];
      if (assoc <= 1) {
	assoc1.show();
	assoc2.hide();
      } else {
	assoc1.hide();
	assoc2.show();
      }

      var sig = p['signal'];
      var pw = 50;
      if (sig > 0) {
	w = sig * pw;
	signal1.animate({width: w, x: this.middle - w}, 1000);
	signal2.animate({width: 0}, 200);
      } else {
	signal1.animate({width: 0, x: this.middle}, 200);
	signal2.animate({width: -1 * sig * pw}, 1000);
      }
    }
  }
});

