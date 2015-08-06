(function() {
  'use strict';
  var _;

  _ = require('lodash');

  module.exports = {
    list: function(key, data, defer) {
      var enckey, f, keybits, list, object, prop;
      if (data) {
        keybits = key.split('.');
        object = data;
        f = 0;
        while (f < keybits.length) {
          enckey = keybits[f];
          if (object[enckey]) {
            object = object[enckey];
          } else {
            if (enckey) {
              defer.reject(null);
            }
          }
          f++;
        }
        list = [];
        for (prop in object) {
          if (prop.indexOf('_') !== 0) {
            list.push(prop);
          }
        }
        defer.resolve(list);
      } else {
        defer.reject(null);
      }
    },
    remove: function(key, data) {
      var enckey, f, keybits, object;
      if (!data) {
        data = {};
      }
      keybits = key.split('.');
      object = data;
      enckey = void 0;
      f = 0;
      while (f < keybits.length - 1) {
        enckey = keybits[f];
        if (object[enckey]) {

        } else {
          object[enckey] = {};
        }
        object = object[enckey];
        f++;
      }
      enckey = keybits[keybits.length - 1];
      delete object[enckey];
      return data;
    },
    set: function(key, value, data) {
      var enckey, f, keybits, object;
      if (!data) {
        data = {};
      }
      keybits = key.split('.');
      object = data;
      f = 0;
      while (f < keybits.length) {
        enckey = keybits[f];
        if (object[enckey]) {

        } else {
          object[enckey] = {};
        }
        object = object[enckey];
        f++;
      }
      object._value = value;
      return data;
    },
    setObject: function(key, value, data) {
      var enckey, f, keybits, object;
      if (!data) {
        data = {};
      }
      keybits = key.split('.');
      object = data;
      f = 0;
      while (f < keybits.length) {
        enckey = keybits[f];
        if (object[enckey]) {

        } else {
          object[enckey] = {};
        }
        object = object[enckey];
        f++;
      }
      _.merge(object, value);
      return data;
    },
    get: function(key, data, defer) {
      var enckey, f, keybits, object;
      if (data) {
        keybits = key.split('.');
        object = data;
        f = 0;
        while (f < keybits.length) {
          enckey = keybits[f];
          if (object[enckey]) {
            object = object[enckey];
          } else {
            defer.reject(null);
          }
          f++;
        }
        defer.resolve(object._value);
      } else {
        defer.reject(null);
      }
      return defer.promise;
    },
    getObject: function(key, data, defer) {
      var enckey, f, keybits, object;
      if (data) {
        keybits = key.split('.');
        object = data;
        f = 0;
        while (f < keybits.length) {
          enckey = keybits[f];
          if (object[enckey]) {
            object = object[enckey];
          } else {
            defer.reject(null);
          }
          f++;
        }
        defer.resolve(object);
      } else {
        defer.reject(null);
      }
      return defer.promise;
    }
  };

}).call(this);
