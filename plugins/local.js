'use strict';

var inquirer = require('inquirer'),
    q = require('q'),
    fs = require('fs'),
    crypto = require('crypto-js'),
    common = require('../common'),
    chalk = require('chalk');

var appDataDir = (process.env.APPDATA || (process.platform == 'darwin' ? process.env.HOME + 'Library/Preference' : '/var/local')) + '/rsafe';

function getData(settings, password, done) {
  var url = crypto.Rabbit.decrypt(settings.url, password).toString(crypto.enc.Utf8);
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

function saveData(settings, password, data) {
  var url = crypto.Rabbit.decrypt(settings.url, password).toString(crypto.enc.Utf8);
  fs.writeFileSync(url, crypto.Rabbit.encrypt(JSON.stringify(data), password).toString());
}

module.exports = {
  name: 'local',
  inquire: function(bundle) {
    console.log(chalk.yellow.bold('\nlocal storage setup\n'));
    var defer = q.defer();
    inquirer.prompt([
      {
        type: 'text',
        name: 'url',
        message: 'storage location (' + appDataDir + ')'
      },
      {
        type: 'text',
        name: 'name',
        message: 'give this safe a name'
      }
      ], function(answers){
        var url = crypto.Rabbit.encrypt(answers.url || appDataDir + '/safe' + bundle.userHash + '.json', bundle.password).toString();
        var name = crypto.Rabbit.encrypt(answers.url || 'local', bundle.password).toString();
        var settings = {
          _type: 'local',
          name: name,
          url: url
        };
        getData(settings, bundle.password, function(data){
          saveData(settings, bundle.password, data);
          bundle.userPlugins.unshift(settings); //only local should unshift(), everyone else should push()
          defer.resolve(bundle);
        })
    });
    return defer.promise;
  },
  remove: function(key, settings, password, confirm) {
    var defer = q.defer();
    getData(settings, password, function(data){
      inquirer.prompt([
        {
          type: 'text',
          name: 'confirm',
          message: 'type ' + confirm + ' to continue'
        }
      ], function(answers){
        if(answers.confirm===confirm) {
          data = common.remove(key, data);
          saveData(settings, password, data);
          defer.resolve(data);
        }
        else {
          defer.reject(null);
        }
      });
    });
    return defer.promise;
  },
  set: function(key, value, settings, password) {
    var defer = q.defer();
    getData(settings, password, function(data){
      data = common.set(key, value, data);
      defer.resolve(data);
    });
    return defer.promise;
  },
  setObject: function(key, value, settings, password) {
    var defer = q.defer();
    getData(settings, password, function(data){
      data = common.setObject(key, value, data);
      defer.resolve(data);
    });
    return defer.promise;
  },
  get: function(key, settings, password) {
    var defer = q.defer();
    getData(settings, password, function(data){
      common.get(key, data, defer);
    });
    return defer.promise;
  },
  getObject: function(key, settings, password) {
    var defer = q.defer();
    getData(settings, password, function(data){
      common.getObject(key, data, defer);
    });
    return defer.promise;
  },
  list: function(key, settings, password) {
    var defer = q.defer();
    getData(settings, password, function(data){
      common.list(key, data, defer);
    });
    return defer.promise;
  },
  syncData: function(data, settings, password) {
    saveData(settings, password, data);
  },
  getData: function(settings, password) {
    var defer = q.defer();
    getData(settings, password, function(data){
      if(data) {
        defer.resolve(data);
      }
      else {
        defer.reject(null);
      }
    });
    return defer.promise;
  }
};
