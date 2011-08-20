/**
 * jQuery Later. Plugin for jQuery
 * Provides a setTimeout/setInterval wrapper
 *
 * Copyright 2010, Sudar Muthu (http://sudarmuthu.com)
 * Released under MIT
 * 
 */
(function($) {
    /**
     * Executes the supplied function in the context of the supplied
     * object 'when' milliseconds later.  Executes the function a
     * single time unless periodic is set to true.
     * 
     * Pretty much copied from http://developer.yahoo.com/yui/3/api/yui-later.js.html
     *
     * @method later
     * @for jQuery
     *
     * @param when {int} the number of milliseconds to wait until the fn
     * is executed.
     * @param o the context object.
     * @param fn {Function|String} the function to execute or the name of
     * the method in the 'o' object to execute.
     * @param data [Array] data that is provided to the function.  This accepts
     * either a single item or an array.  If an array is provided, the
     * function is executed with one parameter for each array item.  If
     * you need to pass a single array parameter, it needs to be wrapped in
     * an array [myarray].
     * @param periodic {boolean} if true, executes continuously at supplied
     * interval until canceled.
     * @return {object} a timer object. Call the cancel() method on this object to
     * stop the timer.
     */

   $.later = function(when, o, fn, data, periodic) {
        when = when || 0;
        o = o || {};
        var m=fn, d=$.makeArray(data), f, r;

        if (typeof fn === "string") {
            m = o[fn];
        }

        if (!m) {
        	// Throw an error about the method
            throw {
                name: 'TypeError',
                message: "The function is undefined."
            }
        }

        f = function() {
            m.apply(o, d);
        };

        r = (periodic) ? setInterval(f, when) : setTimeout(f, when);

        return {
            id: r,
            interval: periodic,
            cancel: function() {
                if (this.interval) {
                    clearInterval(r);
                } else {
                    clearTimeout(r);
                }
            }
        };
    };
 })(jQuery);