
L = new function() {
  this.baseURL = null;


  this.require = function(obj_name, deps, onReady) {
    this._pending_require.push({
      obj_name: obj_name, onReady: onReady
    });
    this._load(deps, true);
    this._checkAllPending(); // we may already have everything we need
  };
  
  // Provides 'obj_name' after loading all 'deps' and executing 'onReady'
  //
  this.provide = function(obj_name, deps, onReady) {
    this._pending_provide.push({
      obj_name: obj_name, deps: this._arr_flatten(deps), onReady: onReady
    });
    this._load(deps, true);
    this._checkAllPending(); // we may already have everything we need
  }
  
  this._load = function(urls, loadParallel) {
    if (urls instanceof Array) {
      if (loadParallel == true) {
        var b = urls.length;
        for (; b;) {
          var url = urls[--b];
          this._load(url, false);
        }
      } else {
        urls = this._arr_flatten(urls);
        var url = urls.shift();
        if (urls.length > 0) {
          var self = this;
          this.provide(null, [url], function() { 
            self._load(urls, false);
          });
        }
        this._loadOne(url);      
      }
    } else {
      this._loadOne(urls);      
    }
  }
    
  this._loadOne = function(url) {
    if (this._requested[url] == true) return;
    this._requested[url] = true;
    var sel = this._createDomFor(url);
    sel.async = true;
    var hel = document.getElementsByTagName("head")[0];
    hel.appendChild(sel);
  };
  
  this._createDomFor = function(url) {
    var abs_url = this._getAbsoluteUrl(url);
    var ext = abs_url.split(".").pop();
    var sel;
    var self = this;
    if (ext != "css") {  // this is a bit of a hack!
      sel = document.createElement("script");      
      sel.src = abs_url;
      sel.onload = sel.onreadystatechange = function () {
        if (!(this.readyState
            && this.readyState !== "complete"
            && this.readyState !== "loaded")) 
        {
          this.onload = this.onreadystatechange = null;
          self._onLoad(url);
        }
      }; 
      
    } else { // css
      sel = document.createElement("link");      
      sel.href = abs_url;
      sel.rel = "stylesheet";
      sel.type ="text/css";
      // there is no consistent support for detecting the successful loading of
      // a css file. Not sure what happens if we simply don't care.
      this._onLoad(url);
      //this._css_el = sel;
    }
    return sel;
  }

  this._getAbsoluteUrl = function(url) {
    if (url.indexOf(':') < 0) { // don't change when it contains protocol
      if (url[0] != '/') { // don't change when starting with '/'
        var s = url.split(".");
        if (s.length == 1) { // append default '.js'
          url = url + '.js';
          s.push('js');
        }
        var ext = s.pop();
        url = this.baseURL + '/' + ext + "/" + url;
      }
    }
    return url;    
  };
  
  this._requested = {};
  this._loaded = {};
  this._pending_require = [];
  this._pending_provide = [];
  this._provided = {};  
  
  this._onLoad = function(url) {
    this._loaded[url] = true;
    this._checkAllPending();
  };
  
  this._checkAllPending = function() {
    this._checkAllPendingProvide();
    this._checkAllPendingRequire();
  }

  this._checkAllPendingRequire = function() {
    var pending = this._pending_require;
    var l = pending.length;
    var still_pending = [];
    for (; l;) {
      var p = pending[--l];
      if (this._provided[p.obj_name]) {
        if (p.onReady) {
          p.onReady();
        }
      } else {
        still_pending.push(p);
      }
    }
    this._pending_require = still_pending;
  }
  
  this._checkAllPendingProvide = function() {
    var pending = this._pending_provide;
    var l = pending.length;
    var still_pending = [];
    for (; l;) {
      var p = pending[--l];
      if (this._all_loaded(p.deps)) {
        if (p.onReady) {
          p.onReady();
        }
        if (p.obj_name) {
          this._provided[p.obj_name] = true;
        }        
      } else {
        still_pending.push(p);
      }
    }
    this._pending_provide = still_pending;
  }

  // Return true if all resources in 'deps' are loaded
  //
  this._all_loaded = function(deps) {
    var loaded = this._loaded;
    var l = deps.length;
    for (; l;) {
      var name = deps[--l];
      if (loaded[name] != true) {
        return false;
      }
    }
    return true;
  }
  
  // this._checkOnePending = function(p) {
    // var deps = p.deps;
    // var loaded = this._loaded;
    // var l = deps.length;
    // for (; l;) {
      // var name = deps[--l];
      // if (loaded[name] != true) {
        // return p;
      // }
    // }
    // // OK, all dependencies fulfilled.
    // var op = p.op;
    // switch (op) {
      // case "load":
        // var next = p.next;
        // var url = next.shift();
        // var new_pending = null;
        // if (next.length > 0) {
          // // load next one
          // new_pending = {op: 'load', deps: [url], next: next};
        // }
        // this._loadOne(url);
        // return new_pending;
      // case "provide":
        // if (p.onReady) {
          // p.onReady();
        // }
        // this._provided[p.obj_name] = true;
        // return null;
      // case "require":
        // if (this._provided[p.obj_name] == true) {
          // if (p.onReady) {
            // p.onReady();
          // }
          // return null; // done
        // }
        // return p;
    // }
    // return null; // not sure what op that is, let's remove it    
  // }
  
  this._arr_flatten = function(array) {
    // http://tech.karbassi.com/2009/12/17/pure-javascript-flatten-array/
    var flat = [];
    for (var i = 0, l = array.length; i < l; i++){
      var type = Object.prototype.toString.call(array[i]).split(' ').pop().split(']').shift().toLowerCase();
      if (type) { flat = flat.concat(/^(array|collection|arguments|object)$/.test(type) ? this._arr_flatten(array[i]) : array[i]); }
    }
    return flat;
  }
};
//L.deps = {};

