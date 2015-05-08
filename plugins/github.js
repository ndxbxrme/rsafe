'use strict';

var inquirer = require('inquirer'),
    q = require('q'),
    fs = require('fs'),
    crypto = require('crypto-js'),
    common = require('../common'),
    chalk = require('chalk'),
    Client = require('node-gist').Client,
    client;


function getData(settings, password, done) {
  var token = crypto.Rabbit.decrypt(settings.token, password).toString(crypto.enc.Utf8);
  var gistUrl = crypto.Rabbit.decrypt(settings.gistUrl, password).toString(crypto.enc.Utf8);
  if(!client) {
    client = new Client({
      token: token
    });
  }
  client.get('/' + gistUrl, function(error, gist){
    if(error) {
      return done({}); 
    }
    if(gist.files && gist.files.length) {
      try{
        var data = crypto.Rabbit.decrypt(gist.files[0].content, password).toString(crypto.enc.Utf8);
        return done(JSON.parse(data));
      } catch(e) {
        return done({});
      }
    }
    else {
      return done({}); 
    }
  });
}

function saveData(settings, password, data) {
  var token = crypto.Rabbit.decrypt(settings.token, password).toString(crypto.enc.Utf8);
  var gistUrl = crypto.Rabbit.decrypt(settings.gistUrl, password).toString(crypto.enc.Utf8);
  gistUrl = gistUrl.replace('https://api.github.com/gists/','');
  if(!client) {
    client = new Client({
      token: token
    });
  }
  var gist = {
    'public': false,
    files: {
      'rsafe.txt': {
        content: crypto.Rabbit.encrypt(JSON.stringify(data), password).toString() 
      }
    }
  };
  client.patch('/' + gistUrl, gist, function(error, g){
    //do nothing
  });
}

module.exports = {
  name: 'github',
  inquire: function(bundle) {
    console.log(chalk.yellow.bold('\nGithub Gist storage setup\n'));
    var defer = q.defer();
    inquirer.prompt([
      {
        type: 'text',
        name: 'user',
        message: 'Github username'
      },
      {
        type: 'password',
        name: 'password',
        message: 'Github password'
      }
      ], function(answers){
        client = new Client({
          user: answers.user,
          password: answers.password,
          token: undefined
        });
        client.path = '';
        var authorization = {
          scopes: ['gist'],
          note: 'rsafe',
          note_url: 'https://github.com/ndxbxrme/rsafe'
        };
        client.post('/authorizations', authorization, function(error, data) {
          if(error) {
            throw error; 
          }
          if(!data.token) {
            throw 'Github login failed'; 
          }
          var token = crypto.Rabbit.encrypt(data.token, bundle.password).toString();
          var settings = {
            _type: 'github',
            name: 'github',
            token: token
          };
          var gist = {
            'public': false,
            files: {
              'rsafe.txt': {
                content: crypto.Rabbit.encrypt(JSON.stringify({}), bundle.password).toString()
              }
            }
          };
          client = new Client({
            token: data.token
          });
          client.post('', gist, function(error, g) {
            if(error) {
              throw error; 
            }
            if(g.message) {
              throw g.message; 
            }
            settings.gistUrl = crypto.Rabbit.encrypt(g.url, bundle.password).toString();
            bundle.userPlugins.push(settings);
            defer.resolve(bundle);
          });
        });
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
