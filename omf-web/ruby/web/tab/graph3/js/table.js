
function oml_table(data, opts, update) {
	if (!update) {
  	$(document).ready(function(){
  		for (var i = 0; i < data.length; i++) {
  			oml_render_table(data[i], i, opts);
  		}
  	})
  } else {
		for (var i = 0; i < data.length; i++) {
      oml_render_rows(data[i], i, opts, true);
    }
	}
}

function oml_render_table(tdata, tcnt, opts){
	/* create table template */
	var tid = "oml_t" + tcnt;
	var h = "<table id='" + tid;
	h += "' cellpadding='0' cellspacing='0' border='0' class='display' width='100%'>";
	h += "<thead><tr>";
	var labels = tdata['labels'];
	for (var i = 0; i < labels.length; i++) {
		h += "<th>" + labels[i] + "</th>";
	}
	h += "</tr></thead>";
	h += "<thead id='data_th'></thead>";
	h += "</table>";
	$('#graph').prepend(h);
	oml_render_rows(tdata, tcnt, opts, false);
}

/* Add rows */
function oml_render_rows(tdata, tcnt, opts, update) {
	
  var rows = tdata['values'];
  var rcnt = rows.length;
	if (rcnt <= 0) {
		return;
	}
  var ccnt = rows[0].length;
	
	var record_id = tdata['record_id']; /* use this column as record id and not display it */
  var tid = "oml_t" + tcnt;
	
  var tbody = $('#' + tid);
	var oid = Math.floor(Math.random() * 10000001);
  for (var i = 0; i < rcnt; i++) {
    var row = rows[i];
    var row_class = (i % 2) == 1 ? "odd" : "even";
		var rid = "tr";
		if (typeof(record_id) == "number") {
			rid = rid + row[record_id]; 
		} else {
			rid = rid + (oid + i);
		}
    var tr = "<tr class='" + row_class + "' id='" + rid + "'>";
    for (var j = 0; j < ccnt; j++) {
			if (record_id != j) {
	  	  tr += "<td>" + row[j] + "</td>";
	    }
    }
    tr += "</tr>"
    tbody.prepend(tr);
		if (update) {
		  $('#' + rid).effect('highlight', {}, 1000);
	  }
  }
}

