(function() {
  var appDataDir, chalk, common, crypto, fs, getData, inquirer, q, saveData;

  getData = function(settings, password, done) {
    var data, e, file, url;
    url = crypto.Rabbit.decrypt(settings.url, password).toString(crypto.enc.Utf8);
    if (fs.existsSync(url)) {
      file = fs.readFileSync(url);
      try {
        data = crypto.Rabbit.decrypt(fs.readFileSync(url).toString(), password).toString(crypto.enc.Utf8);
        return done(JSON.parse(data));
      } catch (_error) {
        e = _error;
        return done({});
      }
    } else {
      return done({});
    }
  };

  saveData = function(settings, password, data) {
    var url;
    url = crypto.Rabbit.decrypt(settings.url, password).toString(crypto.enc.Utf8);
    fs.writeFileSync(url, crypto.Rabbit.encrypt(JSON.stringify(data), password).toString());
  };

  'use strict';

  inquirer = require('inquirer');

  q = require('q');

  fs = require('fs');

  crypto = require('crypto-js');

  common = require('../common');

  chalk = require('chalk');

  appDataDir = (process.env.APPDATA || (process.platform === 'darwin' ? process.env.HOME + 'Library/Preference' : '/var/local')) + '/rsafe';

  module.exports = {
    name: 'local',
    inquire: function(bundle) {
      var defer;
      console.log(chalk.yellow.bold('\nlocal storage setup\n'));
      defer = q.defer();
      inquirer.prompt([
        {
          type: 'text',
          name: 'url',
          message: 'storage location (' + appDataDir + ')'
        }, {
          type: 'text',
          name: 'name',
          message: 'give this safe a name'
        }
      ], function(answers) {
        var name, settings, url;
        url = crypto.Rabbit.encrypt(answers.url || appDataDir + '/safe' + bundle.userHash + '.json', bundle.password).toString();
        name = crypto.Rabbit.encrypt(answers.url || 'local', bundle.password).toString();
        settings = {
          _type: 'local',
          name: name,
          url: url
        };
        getData(settings, bundle.password, function(data) {
          saveData(settings, bundle.password, data);
          bundle.userPlugins.unshift(settings);
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
