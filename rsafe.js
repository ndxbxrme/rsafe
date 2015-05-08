var fs = require('fs'),
    glob = require('glob'),
    path = require('path'),
    inquirer = require('inquirer'),
    crypto = require('crypto-js'),
    chalk = require('chalk'),
    q = require('q'),
    util = require('util'),
    _ = require('lodash'),
    cp = require('safe-copy-paste').silent();

var tokenInterval = 10 * 60 * 1000;
var loginInterval = 2 * 60 * 60 * 1000;

var appDataDir = (process.env.APPDATA || (process.platform == 'darwin' ? process.env.HOME + 'Library/Preference' : '/var/local')) + '/rsafe';
if (!fs.existsSync(appDataDir)){
  fs.mkdirSync(appDataDir);
}
var plugins = [];
var pluginfiles = glob.sync(path.normalize(__dirname) + '/plugins/*.js');
pluginfiles.forEach(function(plugin){
  plugins.push(require(plugin));
});

function loadSettings() {
  var settings = {};
  if(fs.existsSync(appDataDir + '/settings.json')) {
    settings = JSON.parse(fs.readFileSync(appDataDir + '/settings.json'));
  }
  return settings;
}

function saveSettings(settings) {
  fs.writeFileSync(appDataDir + '/settings.json', JSON.stringify(settings));
}
function getPlugin(name) {
  for(var f=0; f<plugins.length; f++) {
    if(plugins[f].name===name) {
      return plugins[f];
    }
  }
}

//getLoggedInUser();
function generateLoginCheck(password) {
  return crypto.Rabbit.encrypt('rain' + Math.floor(Math.random() * 65535) +'storm', password).toString()
}
function generateS() {
  var s = util.inspect(process.versions).length;
  var s1 = 3333;//process.memoryUsage().heapTotal;
  var s2 = util.inspect(module.children).toString().length;
  var s3 = 4444;//parseInt((Math.floor(Date.now()/1000) - process.hrtime()[0]).toString().replace(/[0-9]{1}$/,''));
  return ((s|s3)+s+s3).toString()+s+s3;
}
function generateKey(s,d) {
  return crypto.SHA256(generateKey.toString().length + Math.floor(d/tokenInterval).toString() + s);
}
function parseToken(encToken) {
  var s = generateS();
  var now = Date.now();
  for(var f=now; f>now-loginInterval; f-=tokenInterval) {
    //console.log(f);
    var token = null;
    var key = generateKey(s,f).toString();
    try {
      token = crypto.Rabbit.decrypt(encToken, key).toString(crypto.enc.Utf8);
    } catch(e){}
    if(token) {
      var time = /\/([0-9]+)$/.exec(token);
      if(time && new Date().setTime(time[1]) > new Date()) {
        s = null;
        return token.replace('/' + time[1], '');
      }
    }
  }
  return null;
}
function generateToken(password) {
  var s = generateS();
  var key = generateKey(s, Date.now()).toString();
  return crypto.Rabbit.encrypt(password + '/' + new Date().setTime(new Date().getTime() + loginInterval), key).toString();
}
function checkPassword(loggedInUser, loginCheck, userHash, done) {
  var decCheck = '';
  try {
    decCheck = crypto.Rabbit.decrypt(loginCheck, loggedInUser.password).toString(crypto.enc.Utf8);
  }catch(e){

  }
  if(decCheck.replace(/[0-9]+/gi,'')==='rainstorm') {
    return done(loggedInUser, userHash);
  }
  else {
    console.log(chalk.red.bold('bad password'));
    return done(null, userHash);
  }
}
function getLoggedInUser(done) {
  if(fs.existsSync(appDataDir + '/settings.json')) {
    var settings = loadSettings();
    var loggedInUser;
    for(var key in settings) {
      if(settings[key].loginToken) {
        var password = parseToken(settings[key].loginToken);
        if(password) {
          loggedInUser = settings[key];
          settings[key].loginToken = generateToken(password);
          saveSettings(settings);
          loggedInUser.password = password;
          if(!loggedInUser.password) {
            inquirer.prompt([
              {
                type: 'password',
                name: 'password',
                message: 'password'
              }
            ], function(answers) {
              loggedInUser.password = answers.password;
              return checkPassword(loggedInUser, settings[key].loginCheck, key, done);
            });
          }
          else {
            return checkPassword(loggedInUser, settings[key].loginCheck, key, done);
          }
        }
      }
      else {
        //no login token
      }
    }
    if(!loggedInUser) {
      settings[key].loginToken = undefined;
      saveSettings(settings);
      return done(null, null);
    }
  }
  else {
    console.log(chalk.red.bold('no settings file, run ') + chalk.green.bold('rsafe setup') + chalk.red.bold(' to get going'));
  }
}



function getKey(key, done) {
  if(!key) {
    inquirer.prompt([
      {
        type:'text',
        name:'key',
        message:'key'
      }
    ], function(answers){
      done(answers.key);
    });
  }
  else {
    done(key.replace('_all', ''));
  }
}

function getNewKey(key, done) {
  if(!key) {
    inquirer.prompt([
      {
        type:'text',
        name:'key',
        message:'new key'
      }
      ], function(answers){
        done(answers.key);
      });
    }
    else {
      done(key);
    }
  }

function getValue(value, done) {
  if(!value) {
    inquirer.prompt([
      {
        type:'text',
        name:'value',
        message:'value'
      }
    ], function(answers){
      done(answers.value);
    });
  }
  else {
    done(value);
  }
}

function getUserName(username, done) {
  if(!username) {
    inquirer.prompt([
      {
        type:'text',
        name:'username',
        message:'username'
      }
    ], function(answers){
      done(answers.username);
    });
  }
  else {
    done(username);
  }
}

function setup() {

  inquirer.prompt([
    {
      type:'text',
      name:'username',
      message:'username'
    },
    {
      type:'password',
      name:'password',
      message:'password'
    }
  ], addPlugin);
}

function addPlugin(user, userHash) {
  var settings = loadSettings();
  var pluginChoices = [];
  plugins.forEach(function(plugin){
    pluginChoices.push({name:plugin.name,checked:(plugin.name==='local'&&!user.loginToken)});
  });

  inquirer.prompt([
    {
      type:'checkbox',
      name:'plugins',
      message:'choose storage plugins' + (user.loginToken?' to add':''),
      choices:pluginChoices
    }
  ], function(answers){
    userHash = userHash || crypto.MD5(user.username.toString()).toString();
    var userPlugins = settings[userHash] ? settings[userHash].plugins : [];
    var pluginsToCall = [];
    answers.plugins.forEach(function(pluginChoice){
      plugins.forEach(function(plugin){
        if( plugin.name === pluginChoice ) {
          pluginsToCall.push(plugin.inquire);
        }
      });
    });
    var result = pluginsToCall.reduce(q.when, q({userPlugins:userPlugins,userHash:userHash,password:user.password})).then(function(){
      settings[userHash] = {
        loginCheck:generateLoginCheck(user.password),
        plugins:userPlugins
      };
      saveSettings(settings);
    });
  });
}


module.exports = {
  login: function(argv, done) {
    if(fs.existsSync(appDataDir + '/settings.json')) {
      var settings = loadSettings();
      getUserName(argv._[1], function(username) {
        var userHash = crypto.MD5(username.toString()).toString();
        var userSettings = settings[userHash];
        if(userSettings) {
          inquirer.prompt([
            {
              type: 'password',
              name: 'password',
              message: 'password'
            }
          ], function(answers){
            checkPassword(answers, userSettings.loginCheck, null, function(user){
              if(user) {
                userSettings.loginToken = generateToken(answers.password.toString());
              }
              else {
                userSettings.loginToken = undefined;
              }
              saveSettings(settings);
              if(done) { return done(null, null); }
            });
          });
        }
        else {
          console.log(chalk.blue.bold('do i know you?'));
          if(done) { return done(null, null); }
        }
      });
    }
    else {
      console.log(chalk.red.bold('no settings file, run ') + chalk.green.bold('rsafe setup') + chalk.red.bold(' to get going'));
      if(done) { return done(null, null); }
    }  
  },
  logout: function(argv, done) {
    var settings = loadSettings();
    var loggedInUser;
    for(var key in settings) {
      if(settings[key].loginToken) {
        settings[key].loginToken = undefined;
      }
    }
    saveSettings(settings);
    if(done) { return done(null, null); }
  },
  set: function(argv, done) {
    getLoggedInUser(function(user, userHash){
      if(user) {
        getKey(argv._[1], function(key) {
          if(key) {
            getValue(argv._[2], function(value) {
              function callPlugin(count) {
                getPlugin(user.plugins[count]._type)
                .set(key, value, user.plugins[count], user.password)
                .then(function(data) {
                  if(data) {
                    data.__userHash = userHash;
                    data.__plugins = user.plugins;
                    user.plugins.forEach(function(plugin){
                      getPlugin(plugin._type)
                      .syncData(data, plugin, user.password);
                    });
                    if(done) { return done(null, null); }
                  }
                  else {
                    if(count++<user.plugins.length) {
                      callPlugin(count);
                    }
                  }
                });
              }
              if(value) {
                callPlugin(0);
              }
              else {
                //no value
                if(done) { return done(null, null); }
              }
            });
          }
          else {
            //no key
            if(done) { return done(null, null); }
          }
        });
      }
      else {
        //no user
        console.log(chalk.blue.bold('please login'));
        if(done) { return done(null, null); }
      }
    });    
  },
  remove: function(argv, done) {
    getLoggedInUser(function(user){
      if(user) {
        getKey(argv._[1], function(key) {
          function callPlugin(count) {
            getPlugin(user.plugins[count]._type)
            .remove(key, user.plugins[count], user.password, 'delete')
            .then(function(data) {
              if(data) {
                user.plugins.forEach(function(plugin){
                  getPlugin(plugin._type)
                  .syncData(data, plugin, user.password);
                });
                if(done) { return done(null, null); }
              }
              else {
                if(count++<user.plugins.length) {
                  callPlugin(count);
                }
              }
            });
          }
          if(key) {
            callPlugin(0);
          }
          else {
            //no key
            if(done) { return done(null, null); }
          }
        });
      }
      else {
        //no user
        console.log(chalk.blue.bold('please login'));
        if(done) { return done(null, null); }
      }
    });   
  },
  get: function(argv, done) {
    getLoggedInUser(function(user){
      if(user) {
        getKey(argv._[1], function(key) {
          function callPlugin(count) {
            var defer = q.defer();
            getPlugin(user.plugins[count]._type)
            .get(key, user.plugins[count], user.password)
            .then(function(value){
              if(value) {
                defer.resolve(value);
              }
              else if(count++<user.plugins.length) {
                defer.resolve(callPlugin(count));
              }
              else {
                defer.reject(null);
              }
            });
            return defer.promise;
          }
          if(key) {
            //loop through plugins and get the first good value
            callPlugin(0).then(function(value){
              cp.copy(value);
              console.log(chalk.white.bold('copied to clipboard'));
              if(done) { return done(null, null); }
            }, function(err) {
              console.log(chalk.red.bold('could not find key'));
              if(done) { return done(null, null); }
            });
          }
          else {
            //no key
            if(done) { return done(null, null); }
          }
        });
      }
      else {
        //no user
        console.log(chalk.blue.bold('please login'));
        if(done) { return done(null, null); }
      }
    });    
  },
  rename: function(argv, done) {
    getLoggedInUser(function(user, userHash){
      if(user) {
        getKey(argv._[1], function(key) {
          getNewKey(argv._[2], function(newKey){
            function callPlugin(count) {
              var defer = q.defer();
              var rplugin = getPlugin(user.plugins[count]._type);
              rplugin.getObject(key, user.plugins[count], user.password)
              .then(function(value){
                if(value) {
                  rplugin.remove(key, user.plugins[count], user.password, 'rename')
                  .then(function(){
                    rplugin.setObject(newKey, value, user.plugins[count], user.password)
                    .then(function(data) {
                      if(data) {
                        data.__userHash = userHash;
                        data.__plugins = user.plugins;
                        user.plugins.forEach(function(plugin){
                          getPlugin(plugin._type)
                          .syncData(data, plugin, user.password);
                        });
                      }
                      process.nextTick(function(){
                        defer.resolve();
                      })
                    });
                  });
                }
                else if(count++<user.plugins.length) {
                  defer.resolve(callPlugin(count));
                }
                else {
                  defer.reject(null);
                }
              });
              return defer.promise;
            }
            if(key) {
              //loop through plugins and get the first good value
              callPlugin(0).then(function(){
                console.log(chalk.white.bold('key successfully renamed'));
                if(done) { return done(null, null); }
              }, function(err) {
                console.log(chalk.red.bold('could not find key'));
                if(done) { return done(null, null); }
              });
            }
            else {
              //no key
              if(done) { return done(null, null); }
            }
          });
        });
      }
      else {
        //no user
        console.log(chalk.blue.bold('please login'));
        if(done) { return done(null, null); }
      }
    });   
  },
  list: function(argv, done) {
    getLoggedInUser(function(user){
      if(user) {
        getKey(argv._[1], function(key) {
          function callPlugin(count) {
            var defer = q.defer();
            getPlugin(user.plugins[count]._type)
            .list(key, user.plugins[count], user.password)
            .then(function(list){
              if(list) {
                defer.resolve(list);
              }
              else if(count++<user.plugins.length) {
                defer.resolve(callPlugin(count));
              }
              else {
                defer.reject(null);
              }
            });
            return defer.promise;
          }
          callPlugin(0).then(function(list){
            done(null, _.sortBy(list));
          });
        });
      }
      else {
        //no user
        console.log(chalk.blue.bold('please login'));
        if(done) { return done(null, null); }
      }
    });
  },
  add: function(argv, done) {
    if(argv._.indexOf('plugin') === 1) {
      getLoggedInUser(function(user, userHash){
        if(user) {
          addPlugin(user, userHash);
        } else {
          console.log(chalk.blue.bold('please login'));
          if(done) { return done(null, null); }
        }
      });
    }
  },
  password: function(argv, done) {
    getLoggedInUser(function(user, userHash){
      if(user){
        inquirer.prompt([
          {
            type:'password',
            name:'oldPassword',
            message:'old password'
          },
          {
            type:'password',
            name:'newPassword',
            message:'new password'
          },
          {
            type:'password',
            name:'passwordMatch',
            message:'type it again'
          }
        ], function(answers){
          function callPlugin(count) {
            var settings = loadSettings();
            getPlugin(user.plugins[count]._type)
            .getData(user.plugins[count], answers.oldPassword)
            .then(function(data){
              if(data) {
                //rewrite all plugin properties
                var newPlugins = [];
                user.plugins.forEach(function(plugin){
                  for(var key in plugin) {
                    if(key.indexOf('_')===0) {
                      continue;
                    }
                    try {
                      var decProp = crypto.Rabbit.decrypt(plugin[key],answers.oldPassword).toString(crypto.enc.Utf8);
                      plugin[key] = crypto.Rabbit.encrypt(decProp,answers.newPassword).toString();
                    } catch(e){}
                  }
                  newPlugins.push(plugin);
                });
                settings[userHash].plugins = newPlugins;
                settings[userHash].loginCheck = generateLoginCheck(answers.newPassword);
                saveSettings(settings);
                //rewrite data
                data.__userHash = userHash;
                data.__plugins = user.newPlugins;
                settings[userHash].plugins.forEach(function(plugin){
                  getPlugin(plugin._type)
                  .syncData(data, plugin, answers.newPassword);
                });
                if(done) { return done(null, null); }
              } else {
                if(count++<user.plugins.length) {
                  callPlugin(count);
                }
              }
            });
          }
          //get settings
          user.password = answers.oldPassword;
          checkPassword(user, user.loginCheck, null, function(user){
            if(user) {
              if(answers.newPassword===answers.passwordMatch) {
                callPlugin(0);
              }
              else {
                console.log('passwords must match');
                if(done) { return done(null, null); }
              }
            }
          });
        });
      }
    }); 
  },
  username: function(argv, done) {
    getLoggedInUser(function(user, userHash){
      if(user){
        inquirer.prompt([
          {
            type:'text',
            name:'oldUsername',
            message:'old username'
          },
          {
            type:'text',
            name:'newUsername',
            message:'new username'
          }
        ], function(answers){
          var settings = loadSettings();
          settings[userHash] = undefined;
          var newHash = crypto.MD5(answers.newUsername).toString();
          if(!settings[newHash]){
            user.password = undefined;
            settings[newHash] = user;
            saveSettings(settings);
          }
          if(done) { return done(null, null); }
        });
      }
    }); 
  },
  help: function(argv, done) {
    console.log('');
    console.log(chalk.yellow.bold('available commands'));
    console.log('');
    console.log(chalk.green.bold('setup') + ' - get started');
    console.log(chalk.green.bold('login'));
    console.log(chalk.green.bold('logout'));
    console.log(chalk.green.bold('set') + ' - set data');
    console.log(chalk.green.bold('get') + ' - get data');
    console.log(chalk.green.bold('list') + ' - list keys');
    console.log(chalk.green.bold('remove') + ' - delete key and data');
    console.log(chalk.green.bold('rename') + ' - rename a key');
    console.log(chalk.green.bold('add plugin') + ' - add a storage plugin');
    console.log(chalk.green.bold('username') + ' - change your local username');
    console.log(chalk.green.bold('password') + ' - change your password');
    console.log(chalk.green.bold('help') + ' - this list of commands');
    if(done) { done(null, null); }
  },
};