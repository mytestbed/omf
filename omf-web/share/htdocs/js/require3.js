
L = new function() {
  this.baseURL = null;


  // deps: module name starting with '#'
  // onReady: last argument should be a function
  //
  this.require = function(deps, onReady) {
    var deps = Array.prototype.slice.call(arguments);  
    var onReady = deps.pop();
    
    var absDeps = this._calculate_required(deps);
    
    this._pending_require.push({
      deps: absDeps, onReady: onReady
    });
    this._load(deps, true);
    this._checkAllPending(); // we may already have everything we need
  };
  
  this._calculate_required = function(deps) {    
    var fDeps = this._arr_flatten(deps);
    var absDeps = [];
    var i = fDeps.length;
    for (; i;) {
      var d = fDeps[--i];
      if (d[0] == '#') {
        // module
        //modules.push(d.split('#')[1]);
        absDeps.push(d);
      } else {
        absDeps.push(this._getAbsoluteUrl(d));
      }
    }
    return absDeps;
  };
  
  
  // Provides 'obj_name' after loading all 'deps' and executing 'onReady'
  //
  this.provide = function(obj_name, deps, onReady) {
    var absDeps = this._calculate_required(deps);

    this._pending_provide.push({
      obj_name: obj_name, deps: absDeps, onReady: onReady
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
          // load one at a time 
          this.require(url, function() {
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
    if (url[0] == '#') {
      return; // modules are 'provided'
    }
    var abs_url = this._getAbsoluteUrl(url);
    if (this._requested[abs_url] == true) return;
    this._requested[abs_url] = true;
    var sel = this._createDomFor(abs_url);
    sel.async = true;
    var hel = document.getElementsByTagName("head")[0];
    hel.appendChild(sel);
  };
  
  this._createDomFor = function(url) {
    var ext = url.split(".").pop();
    var sel;
    var self = this;
    if (ext != "css") {  // this is a bit of a hack!
      sel = document.createElement("script");      
      sel.src = url;
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
      sel.href = url;
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
  
  this._onLoad = function(url) {
    this._loaded[url] = true;
    this._checkAllPending();
  };
  
  this._checkAllPending = function() {
    this._checkAllPendingProvide();
    this._checkAllPendingRequire();
  }

  this._checkAllPendingRequire = function() {
    var pending = this._pending_require.slice(0);
    var l = pending.length;
    var still_pending = [];
    for (; l;) {
      var p = pending[--l];
      if (this._all_loaded(p.deps)) {
        if (p.processed != true) { // avoid infinite recursions
          p.processed = true
          if (p.onReady) {
            //try {
              p.onReady();
            // } catch(err) {
              // //Handle errors here
              // var st = printStackTrace({e: err});  
              // console.log(st.join('\n'));            
              // var x = err;
            // }
            
            // As onReady may call this library as well, better start
            // checking from scratch
            this._checkAllPendingRequire();
            return;
          }            
        }
      } else {
        still_pending.push(p);
      }
    }
    this._pending_require = still_pending;
  }
  
  // Return true if all dependencies are met
  // this._checkOnePendingRequire = function(descr) {
    // var deps = descr.deps;
    // if (! this._all_loaded(deps)) {
      // return false;
    // }
    // var modules = descr.modules;
    // // Also need to check on pending modules
    // if (descr.onReady) {
      // descr.onReady();
    // }
    // return true;
  // }
  
  this._checkAllPendingProvide = function() {
    var pending = this._pending_provide.slice(0);
    var l = pending.length;
    var still_pending = [];
    for (; l;) {
      var p = pending[--l];
      if (this._all_loaded(p.deps)) {
        if (p.processed != true) { // avoid infinite recursions
          p.processed = true
          if (p.onReady) {
            try {
              p.onReady();
            } catch(err) {
              //Handle errors here
              var s = printStackTrace({e: err});
              console.log(s);            
            }
          }  
          if (p.obj_name) {
            this._loaded["#" + p.obj_name] = true;
          }
          // As onReady may call this library as well, better start
          // checking from scratch
          this._checkAllPendingProvide();
          return;          
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

