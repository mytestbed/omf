// 
//L.provide('OML.table2', ["graph/abstract_widget", "#OML.abstract_widget"], function () {
L.provide('OML.table2', ["graph/abstract_widget", "#OML.abstract_widget", [

                                '/resource/vendor/jquery/jquery-ui.custom.min.js',
                                '/resource/vendor/jquery/jquery.event.drag.js',
                              ], [

                                '/resource/vendor/slickgrid/slick.core.js',
                                '/resource/vendor/slickgrid/slick.formatters.js',
                                '/resource/vendor/slickgrid/slick.editors.js',
                                '/resource/vendor/slickgrid/plugins/slick.rowselectionmodel.js',
                                '/resource/vendor/slickgrid/slick.grid.js',
                                '/resource/vendor/slickgrid/slick.dataview.js',
                                '/resource/vendor/slickgrid/controls/slick.pager.js',
                                '/resource/vendor/slickgrid/controls/slick.columnpicker.js',
                              ],
                                //'/resource/vendor/slickgrid/slick.grid.css',                                
                                '/resource/css/theme/bright/slickgrid.css',                                
                                
                              ], function () {

  if (typeof(OML) == "undefined") OML = {};
  
  OML.table2 = OML.abstract_widget.extend({
    defaults: function() {
      return this.deep_defaults({
        // add defaults
        topts: {
          enableCellNavigation: false,
          enableColumnReorder: false,
          forceFitColumns: true,
          //autoHeight: true
        }
      }, OML.table2.__super__.defaults.call(this));      
    },    

    initialize: function(opts) {
      OML.table2.__super__.initialize.call(this, opts);
      this.base_el
        .style('height', '600px')
        ;
      this.update();
    },
    
    redraw: function(data) {
      
      var grid,
          data = [],
          columns = [
            { id: "title", name: "Title", field: "title", width: 0, sortable: true },
            { id: "c1", name: "Sort 1", field: "c1", width: 0, sortable: true },
            { id: "c2", name: "Sort 2", field: "c2", width: 0, sortable: true },
            { id: "c3", name: "Sort 3", field: "c3", width: 0, sortable: true },
            { id: "c4", name: "Sort 4", field: "c4", width: 0, sortable: true },
            { id: "c5", name: "Sort 5", field: "c5", width: 0, sortable: true },
            { id: "c6", name: "Sort 6", field: "c6", width: 0, sortable: true },
            { id: "c7", name: "Sort 7", field: "c7", width: 0, sortable: true }
          ],
          numberOfItems = 250, items = [], indices, isAsc = true, currentSortCol = { id: "title" }, i;
    
      // Copies and shuffles the specified array and returns a new shuffled array.
      function randomize(items) {
        var randomItems = $.extend(true, null, items), randomIndex, temp, index;
        for (index = items.length; index-- > 0;) {
          randomIndex = Math.round(Math.random() * items.length - 1);
          if (randomIndex > -1) {
            temp = randomItems[randomIndex];
            randomItems[randomIndex] = randomItems[index];
            randomItems[index] = temp;
          }
        }
        return randomItems;
      }
    
      /// Build the items and indices.
      for (i = numberOfItems; i-- > 0;) {
        items[i] = i;
        data[i] = {
          title: "Task ".concat(i + 1)
        };
      }
      indices = { title: items, c1: randomize(items), c2: randomize(items), c3: randomize(items), c4: randomize(items), c5: randomize(items), c6: randomize(items), c7: randomize(items) };
    
      // Assign values to the data.
      for (i = numberOfItems; i-- > 0;) {
        data[indices.c1[i]].c1 = "Value ".concat(i + 1);
        data[indices.c2[i]].c2 = "Value ".concat(i + 1);
        data[indices.c3[i]].c3 = "Value ".concat(i + 1);
        data[indices.c4[i]].c4 = "Value ".concat(i + 1);
        data[indices.c5[i]].c5 = "Value ".concat(i + 1);
        data[indices.c6[i]].c6 = "Value ".concat(i + 1);
        data[indices.c7[i]].c7 = "Value ".concat(i + 1);
      }
    
      // Define function used to get the data and sort it.
      function getItem(index) {
        return isAsc ? data[indices[currentSortCol.id][index]] : data[indices[currentSortCol.id][(data.length - 1) - index]];
      }
      function getLength() {
        return data.length;
      }
    
      grid = new Slick.Grid(this.opts.base_el, {getLength: getLength, getItem: getItem}, columns, this.opts.topts);
      grid.onSort.subscribe(function (e, args) {
        currentSortCol = args.sortCol;
        isAsc = args.sortAsc;
        grid.invalidateAllRows();
        grid.render();
      });
      
    },
  })
})
