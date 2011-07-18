
/*
require_obj('$.ui', {url: ['/resource/css/table.css', 'jquery', 'jquery-ui-1.8.4.custom.min']}, function() { 
*/
require_obj('$.ui', {url: ['/resource/css/table.css', 'jquery', 'jquery-ui-1.8.4.custom.min']}, function() { 

  OML['table'] = function(opts){
    this.opts = opts;

    this.init = function(opts) {
      /* create table template */
      var base_el = opts.base_el || '#table'
      var tid = base_el.substr(1) + "_t";
      var h = "<table id='" + tid;
      h += "' cellpadding='0' cellspacing='0' border='0' class='oml_table' width='100%'>";
      h += "<thead><tr>";
      var labels = opts.labels;
      for (var i = 0; i < labels.length; i++) {
        h += "<th class='oml_c" + i + " oml_" + labels[i] + "'>" + labels[i] + "</th>";
      }
      h += "</tr></thead>";
      h += "<thead id='data_th'></thead>";
      h += "</table>";
      $(base_el).prepend(h);
      this.table_el = $('#' + tid);
       
      var data = opts.data;
      if (data) this.update(data);
    };

    this.update = function(data) {
      // there should only be one series and it's name should be '_'
      var rows = data[0].data;
      this.render_rows(rows, false);
    };

    /* Add rows */
    this.render_rows = function(rows, update){

      var rcnt = rows.length;
      if (rcnt <= 0) {
        return;
      }
      var ccnt = rows[0].length;

      var tbody = this.table_el;
      var oid = Math.floor(Math.random() * 10000001);
      for (var i = 0; i < rcnt; i++) {
        var row = rows[i];
        var row_class = (i % 2) == 1 ? "odd" : "even";

        /*** 
         * We may want to use one of the incoming columns as a record id which would allow
         * us to update a row, nstead of just adding it.
         * 
         * TODO: Implement
        var rid = "tr";
        var record_id = tdata['record_id'];
        if (typeof(record_id) == "number") {
          rid = rid + row[record_id];
        }
        else {
          rid = rid + (oid + i);
        }
        **/
        rid = 'tr' + (oid + i);
        var labels = opts.labels;
        var tr = "<tr class='" + row_class + "' id='" + rid + "'>";
        for (var j = 0; j < ccnt; j++) {
          /** if (record_id != j) { 
            tr += "<td>" + row[j] + "</td>";
          }
          **/
          tr += "<td class='oml_c" + j + " oml_" + labels[j] + "'>" + row[j] + "</th>";
        }
        tr += "</tr>"
        tbody.prepend(tr);
        if (update) {
          $('#' + rid).effect('highlight', {}, 1000);
        }
      }
    };
    
    this.init(opts);

  }
});

/*
  Local Variables:
  mode: Javascript
  tab-width: 2
  indent-tabs-mode: nil
  End:
*/