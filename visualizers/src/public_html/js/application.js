// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults


var PubType = {
    loadEditor : function(pub_id) {
        type = $('pubTypeSelector').value;
        if (type == "") {
            Element.hide('typeEditorContainer');
        } else {
            new Ajax.Request('/publication/load_type_editor', {
                asynchronous : true, 
                evalScripts : true,
                method : 'get', 
                parameters: 'id=' + pub_id + '&type=' + type
            }); 
        }
        return false;
    }
};

var ListFilter = {
    observe : function(field) {
        new Form.Element.EventObserver(field, function(element, value) {
            $('updateSpinner').show();
            new Ajax.Request('/publication/browse_ajax', {
                asynchronous:true, 
                evalScripts:true, 
                parameters:$("list_filter_form").serialize()
            })
        });
        return false;
    }
};

var ListOrder = {
    observe : function(field) {
        new Form.Element.EventObserver(field, function(element, value) {
            $('updateSpinner').show();
            new Ajax.Request('/browse/order_ajax', {
                asynchronous:true, 
                evalScripts:true, 
                parameters:$("order_form").serialize()
            })
        });
        return false;
    }
};


// The addLoadEvent function takes as an argument another function which should be executed 
// once the page has loaded. Unlike assigning directly to window.onload, the function adds 
// the event in such a way that any previously added onload functions will be executed first.
//
// The way this works is relatively simple: if window.onload has not already been assigned 
// a function, the function passed to addLoadEvent is simply assigned to window.onload. If 
// window.onload has already been set, a brand new function is created which first calls 
// the original onload handler, then calls the new handler afterwards.
//
// addLoadEvent has one very important property: it will work even if something has previously 
// been assigned to window.onload without using addLoadEvent itself. This makes it ideal for 
// use in scripts that may be executing along side other scripts that have already been 
// registered to execute once the page has loaded.
//
function addLoadEvent(func) {
  var oldonload = window.onload;
  if (typeof window.onload != 'function') {
    window.onload = func;
  }
  else {
    window.onload = function() {
      if (oldonload) {
        oldonload();
      }
      func();
    }
  }
}

function addResizeEvent(func) {
  var oldonresize = window.onresize;
  if (typeof window.onresize != 'function') {
    window.onresize = func;
  }
  else {
    window.onresize = function() {
      if (oldonresize) {
        oldonresize();
      }
      func();
    }
  }
}


