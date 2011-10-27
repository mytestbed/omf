

L.provide('OML.table', ["table.css", ["jquery.js", "jquery.dataTables.js"]], function () {
  if (typeof(OML) == "undefined") {
    OML = {};
  }
  
  OML['table'] = function(opts){
    this.opts = opts;

    this.init = function(opts) {
      /* create table template */
      var base_el = opts.base_el || '#table'
      
      
      var tid = base_el.substr(1) + "_t";
      var tbid = base_el.substr(1) + "_tb";
      var h = "<table id='" + tid;
      h += "' cellpadding='0' cellspacing='0' border='0' class='oml_table' width='100%'>";
      h += "<thead><tr>";
      var schema = this.schema = opts.schema;
      if (schema) {
        for (var i = 0; i < schema.length; i++) {
          var col = schema[i];
          h += "<th class='oml_c" + i + " oml_" + col.name + "'>" + col.name + "</th>";
        }
      }
      h += "</tr></thead>";
      h += "<tbody id='" + tbid + "'></tbody>";
      h += "</table>";
      $(base_el).prepend(h);
      this.table_el = $('#' + tid);
      this.tbody_el = $('#' + tbid);      
       
      // var b = $(base_el)
      // b.dataTable();
      this.dataTable = this.table_el.dataTable();
       
      var data = opts.data;
      if (data) this.update(data);
    };

    this.update = function(data) {
      this.render_rows(data, false);
    };

    /* Add rows */
    this.render_rows = function(rows, update) {
      if (this.dataTable) {
        this.dataTable.fnAddData(rows);
        // var rcnt = rows.length;
        // for (var i = 0; i < rcnt; i++) {
          // var row = rows[i];
          // this.dataTable.fnAddData(row)
        // }
        return;
      }

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
        var schema = this.schema;
        for (var j = 0; j < ccnt; j++) {
          tr += "<td class='oml_c" + j;
          var col = schema[i];
          if (col) {
            tr += " oml_" + col.name;
          }
          tr += "'>" + row[j] + "</th>";
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