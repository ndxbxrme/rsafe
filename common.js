'use strict';

module.exports = {
  list: function(key, data, defer) {
    if(data) {
      var keybits = key.split('.');
      var object = data;
      for(var f=0; f<keybits.length; f++) {
        var enckey = /*crypto.Rabbit.encrypt(*/keybits[f]/*, password).toString()*/;
        if(object[enckey]) {
          object = object[enckey];
        }
        else {
          if(enckey) {
            defer.reject(null);
          }
        }
      }
      var list = [];
      for(var prop in object) {
        if(prop.indexOf('_')!==0) {
          list.push(prop);
        }
      }
      defer.resolve(list);
    }
    else {
      defer.reject(null);
    }
  },
  remove: function(key, data) {
    if(!data) {
      data = {};
    }
    var keybits = key.split('.');
    var object = data;
    var enckey;
    for(var f=0; f<keybits.length-1; f++) {
      enckey = keybits[f];
      if(object[enckey]) {

      }
      else {
        object[enckey] = {};
      }
      object = object[enckey];
    }
    enckey = keybits[keybits.length-1];
    delete object[enckey];
    return data;
  },
  set: function(key, value, data) {
    if(!data) {
      data = {};
    }
    var keybits = key.split('.');
    var object = data;
    for(var f=0; f<keybits.length; f++) {
      var enckey = keybits[f];
      if(object[enckey]) {

      }
      else {
        object[enckey] = {};
      }
      object = object[enckey];
    }
    object._value = value;
    return data;
  },
  get: function(key, data, defer) {
    if(data) {
      var keybits = key.split('.');
      var object = data;
      for(var f=0; f<keybits.length; f++) {
        var enckey = /*crypto.Rabbit.encrypt(*/keybits[f]/*, password).toString()*/;
        if(object[enckey]) {
          object = object[enckey];
        }
        else {
          defer.reject(null);
        }
      }
      defer.resolve(object._value);
    }
    else {
      defer.reject(null);
    }
    return defer.promise;
  }
};
