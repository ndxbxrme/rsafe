'use strict';

var inquirer = require('inquirer'),
    q = require('q'),
    mongoose = require('mongoose'),
    crypto = require('crypto-js'),
    common = require('../common'),
    chalk = require('chalk');

var userHash = '';

var dataSchema = mongoose.Schema({
  _hash: String,
  data: String
});
var Data = mongoose.model('Data', dataSchema);

function getData(settings, password, done) {
  var url = crypto.Rabbit.decrypt(settings.url, password).toString(crypto.enc.Utf8);
  var hash = settings._hash;
  var mongoUsername = crypto.Rabbit.decrypt(settings.username, password).toString(crypto.enc.Utf8);
  var mongoPassword = crypto.Rabbit.decrypt(settings.password, password).toString(crypto.enc.Utf8);
  mongoose.connect(url, function(err){
    Data.findOne({_hash:hash})
    .exec(function(err, data){
      mongoose.connection.close();
      try {
        var output = crypto.Rabbit.decrypt(data.data, password).toString(crypto.enc.Utf8);
        return done(JSON.parse(output));
      } catch(e) {
        return done({});
      }
      return done({});
    });
  });
}

function saveData(settings, password, data) {
  var url = crypto.Rabbit.decrypt(settings.url, password).toString(crypto.enc.Utf8);
  var hash = settings._hash;
  var mongoUsername = crypto.Rabbit.decrypt(settings.username, password).toString(crypto.enc.Utf8);
  var mongoPassword = crypto.Rabbit.decrypt(settings.password, password).toString(crypto.enc.Utf8);

  mongoose.connect(url, function(err){
    Data.findOne({_hash:hash})
    .exec(function(err, data){
      if(data) {
        data.data = crypto.Rabbit.encrypt(JSON.stringify(data), password).toString();
        data.save(function(err){
          mongoose.connection.close();
        });
      } else {
        var newData = new Data();
        newData._hash = hash;
        newData.data = crypto.Rabbit.encrypt(JSON.stringify(data), password).toString();
        newData.save(function(err){
          mongoose.connection.close();
        });
      }
    });
  });
}

module.exports = {
  name: 'mongodb',
  inquire: function(bundle) {
    console.log(chalk.yellow.bold('\nmongodb storage setup\n'));
    var defer = q.defer();
    inquirer.prompt([
      {
        type: 'text',
        name: 'url',
        message: 'mongodb url (leave blank for default)'
      },
      {
        type: 'text',
        name: 'username',
        message: 'username'
      },
      {
        type: 'text',
        name: 'password',
        message: 'password'
      }
      ], function(answers){
        var url = crypto.Rabbit.encrypt(answers.url || 'mongodb://localhost:27017/rsafe', bundle.password).toString();
        var mongoUsername = crypto.Rabbit.encrypt(answers.username.toString(), bundle.password).toString();
        var mongoPassword = crypto.Rabbit.encrypt(answers.password.toString(), bundle.password).toString();
        var settings = {
          _type: 'mongodb',
          url: url,
          _hash: bundle.userHash,
          username: mongoUsername,
          password: mongoPassword
        };
        getData(settings, bundle.password, function(data){
          saveData(settings, bundle.password, data);
          bundle.userPlugins.push(settings); //only local should unshift(), other plugins should push()
          defer.resolve(bundle);
        })
    });
    return defer.promise;
  },
  remove: function(key, settings, password) {
    var defer = q.defer();
    getData(settings, password, function(data){
      inquirer.prompt([
        {
          type: 'text',
          name: 'confirm',
          message: 'type delete to continue'
        }
        ], function(answers){
          if(answers.confirm==='delete') {
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
        //saveData(settings, password, data);
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
