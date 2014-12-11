'use strict';

var inquirer = require('inquirer'),
    q = require('q'),
    fs = require('fs'),
    crypto = require('crypto-js'),
    common = require('../common');

var password = '';
var userHash = '';

function getData(url, done) {
  url = crypto.Rabbit.decrypt(url, password).toString(crypto.enc.Utf8);
  if(fs.existsSync(url)) {
    var file = fs.readFileSync(url);
    try{
      var data = crypto.Rabbit.decrypt(fs.readFileSync(url).toString(), password).toString(crypto.enc.Utf8);
      return done(JSON.parse(data));
    } catch(e) {
      return done({});
    }
  }
  else {
    return done({});
  }
}

function saveData(url, data) {
  url = crypto.Rabbit.decrypt(url, password).toString(crypto.enc.Utf8);
  fs.writeFileSync(url, crypto.Rabbit.encrypt(JSON.stringify(data), password).toString());
}

module.exports = {
  name: 'local',
  inquire: function(userPlugins) {
    var defer = q.defer();
    inquirer.prompt([
      {
        type: 'text',
        name: 'url',
        message: 'storage location (leave blank for default)'
      }
      ], function(answers){
        var url = crypto.Rabbit.encrypt(answers.url || __dirname + '/safe' + userHash + '.json', password).toString();
        getData(url, function(data){
          saveData(url, data);
          userPlugins.unshift({ //only local should unshift(), other plugins should push()
            type: 'local',
            url: url
          });
          defer.resolve(userPlugins);
        })
    });
    return defer.promise;
  },
  remove: function(key, settings, _password) {
    var defer = q.defer();
    password = _password;
    getData(settings.url, function(data){
      inquirer.prompt([
        {
          type: 'text',
          name: 'confirm',
          message: 'type delete to continue'
        }
      ], function(answers){
        if(answers.confirm==='delete') {
          data = common.remove(key, data);
          saveData(settings.url, data);
          defer.resolve(data);
        }
        else {
          defer.reject(null);
        }
      });
    });
    return defer.promise;
  },
  set: function(key, value, settings, _password) {
    var defer = q.defer();
    password = _password;
    getData(settings.url, function(data){
      data = common.set(key, value, data);
      //saveData(settings.url, data);
      defer.resolve(data);
    });
    return defer.promise;
  },
  get: function(key, settings, _password) {
    var defer = q.defer();
    password = _password;
    getData(settings.url, function(data){
      common.get(key, data, defer);
    });
    return defer.promise;
  },
  list: function(key, settings, _password) {
    var defer = q.defer();
    password = _password;
    getData(settings.url, function(data){
      common.list(key, data, defer);
    });
    return defer.promise;
  },
  syncData: function(data, settings, _password) {
    password = _password;
    saveData(settings.url, data);
  },
  getData: function(settings, _password) {
    var defer = q.defer();
    password = _password;
    getData(settings.url, function(data){
      if(data) {
        defer.resolve(data);
      }
      else {
        defer.reject(null);
      }
    });
    return defer.promise;
  },
  setPassword: function(_password) {
    password = _password;
  },
  setUserHash: function(_userHash) {
    userHash = _userHash;
  }
};
