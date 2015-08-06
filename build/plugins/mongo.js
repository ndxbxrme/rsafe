(function() {
  var Data, chalk, common, crypto, dataSchema, getData, inquirer, mongoose, q, saveData, userHash;

  getData = function(settings, password, done) {
    var hash, mongoPassword, mongoUsername, url;
    url = crypto.Rabbit.decrypt(settings.url, password).toString(crypto.enc.Utf8);
    hash = settings._hash;
    mongoUsername = crypto.Rabbit.decrypt(settings.username, password).toString(crypto.enc.Utf8);
    mongoPassword = crypto.Rabbit.decrypt(settings.password, password).toString(crypto.enc.Utf8);
    mongoose.connect(url, function(err) {
      Data.findOne({
        _hash: hash
      }).exec(function(err, data) {
        var e, output;
        mongoose.connection.close();
        try {
          output = crypto.Rabbit.decrypt(data.data, password).toString(crypto.enc.Utf8);
          return done(JSON.parse(output));
        } catch (_error) {
          e = _error;
          return done({});
        }
        return done({});
      });
    });
  };

  saveData = function(settings, password, data) {
    var hash, mongoPassword, mongoUsername, url;
    url = crypto.Rabbit.decrypt(settings.url, password).toString(crypto.enc.Utf8);
    hash = settings._hash;
    mongoUsername = crypto.Rabbit.decrypt(settings.username, password).toString(crypto.enc.Utf8);
    mongoPassword = crypto.Rabbit.decrypt(settings.password, password).toString(crypto.enc.Utf8);
    mongoose.connect(url, function(err) {
      Data.findOne({
        _hash: hash
      }).exec(function(err, dbdata) {
        var newData;
        if (dbdata) {
          dbdata.data = crypto.Rabbit.encrypt(JSON.stringify(data), password).toString();
          dbdata.save(function(err) {
            mongoose.connection.close();
          });
        } else {
          newData = new Data;
          newData._hash = hash;
          newData.data = crypto.Rabbit.encrypt(JSON.stringify(data), password).toString();
          newData.save(function(err) {
            mongoose.connection.close();
          });
        }
      });
    });
  };

  'use strict';

  inquirer = require('inquirer');

  q = require('q');

  mongoose = require('mongoose');

  crypto = require('crypto-js');

  common = require('../common');

  chalk = require('chalk');

  userHash = '';

  dataSchema = mongoose.Schema({
    _hash: String,
    data: String
  });

  Data = mongoose.model('Data', dataSchema);

  module.exports = {
    name: 'mongodb',
    inquire: function(bundle) {
      var defer;
      console.log(chalk.yellow.bold('\nmongodb storage setup\n'));
      defer = q.defer();
      inquirer.prompt([
        {
          type: 'text',
          name: 'url',
          message: 'mongodb url (leave blank for default)'
        }, {
          type: 'text',
          name: 'username',
          message: 'username'
        }, {
          type: 'password',
          name: 'password',
          message: 'password'
        }, {
          type: 'text',
          name: 'name',
          message: 'give this safe a name'
        }
      ], function(answers) {
        var mongoPassword, mongoUsername, name, settings, url;
        url = crypto.Rabbit.encrypt(answers.url || 'mongodb://localhost:27017/rsafe', bundle.password).toString();
        name = crypto.Rabbit.encrypt(answers.name || 'mongo', bundle.password).toString();
        mongoUsername = crypto.Rabbit.encrypt(answers.username.toString(), bundle.password).toString();
        mongoPassword = crypto.Rabbit.encrypt(answers.password.toString(), bundle.password).toString();
        settings = {
          _type: 'mongodb',
          name: name,
          url: url,
          _hash: bundle.userHash,
          username: mongoUsername,
          password: mongoPassword
        };
        getData(settings, bundle.password, function(data) {
          saveData(settings, bundle.password, data);
          bundle.userPlugins.push(settings);
          defer.resolve(bundle);
        });
      });
      return defer.promise;
    },
    remove: function(key, settings, password, confirm) {
      var defer;
      defer = q.defer();
      getData(settings, password, function(data) {
        inquirer.prompt([
          {
            type: 'text',
            name: 'confirm',
            message: 'type ' + confirm + ' to continue'
          }
        ], function(answers) {
          if (answers.confirm === confirm) {
            data = common.remove(key, data);
            saveData(settings, password, data);
            defer.resolve(data);
          } else {
            defer.reject(null);
          }
        });
      });
      return defer.promise;
    },
    set: function(key, value, settings, password) {
      var defer;
      defer = q.defer();
      getData(settings, password, function(data) {
        data = common.set(key, value, data);
        defer.resolve(data);
      });
      return defer.promise;
    },
    setObject: function(key, value, settings, password) {
      var defer;
      defer = q.defer();
      getData(settings, password, function(data) {
        data = common.setObject(key, value, data);
        defer.resolve(data);
      });
      return defer.promise;
    },
    get: function(key, settings, password) {
      var defer;
      defer = q.defer();
      getData(settings, password, function(data) {
        common.get(key, data, defer);
      });
      return defer.promise;
    },
    getObject: function(key, settings, password) {
      var defer;
      defer = q.defer();
      getData(settings, password, function(data) {
        common.getObject(key, data, defer);
      });
      return defer.promise;
    },
    list: function(key, settings, password) {
      var defer;
      defer = q.defer();
      getData(settings, password, function(data) {
        common.list(key, data, defer);
      });
      return defer.promise;
    },
    syncData: function(data, settings, password) {
      saveData(settings, password, data);
    },
    getData: function(settings, password) {
      var defer;
      defer = q.defer();
      getData(settings, password, function(data) {
        if (data) {
          defer.resolve(data);
        } else {
          defer.reject(null);
        }
      });
      return defer.promise;
    }
  };

}).call(this);
