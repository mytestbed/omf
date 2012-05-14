

L.provide('OML.table', ["table2.css", ["/resource/vendor/jquery/jquery.js", "/resource/vendor/jquery/jquery.dataTables.js"]], function () {
  if (typeof(OML) == "undefined") {
    OML = {};
  }

  OML['table'] = Backbone.Model.extend({

    initialize: function(opts) {
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

      this.dataTable = this.table_el.dataTable({
        "sPaginationType": "full_numbers"
      });

      var data = opts.data;
      if (data) this.update(data);
    },

    update: function(sources) {
      if (! (sources instanceof Array)) {
        throw "Expected an array"
      }
      if (sources.length != 1) {
        throw "Can only process a SINGLE source"
      }
      var data_source = OML.data_sources[sources[0].stream];
      if ((this.data = data_source.events) == null) {
        throw "Missing events array in data source"
      }
      this.render_rows(this.data, false);
    },


    /* Add rows */
    render_rows: function(rows, update) {
      this.dataTable.fnClearTable();
      this.dataTable.fnAddData(rows);
    }

  })
});

/*
  Local Variables:
  mode: Javascript
  tab-width: 2
  indent-tabs-mode: nil
  End:
*/
