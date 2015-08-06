fs = require('fs')
glob = require('glob')
path = require('path')
inquirer = require('inquirer')
crypto = require('crypto-js')
chalk = require('chalk')
q = require('q')
util = require('util')
_ = require('lodash')
cp = require('safe-copy-paste').silent()
tokenInterval = 10 * 60 * 1000
loginInterval = 2 * 60 * 60 * 1000
appDataDir = (process.env.APPDATA or (if process.platform == 'darwin' then process.env.HOME + 'Library/Preference' else '/var/local')) + '/rsafe'

loadSettings = ->
  settings = {}
  if fs.existsSync(appDataDir + '/settings.json')
    settings = JSON.parse(fs.readFileSync(appDataDir + '/settings.json'))
  settings

saveSettings = (settings) ->
  fs.writeFileSync appDataDir + '/settings.json', JSON.stringify(settings)
  return

getPlugin = (name) ->
  f = 0
  while f < plugins.length
    if plugins[f].name == name
      return plugins[f]
    f++
  return

#getLoggedInUser();

generateLoginCheck = (password) ->
  crypto.Rabbit.encrypt('rain' + Math.floor(Math.random() * 65535) + 'storm', password).toString()

generateS = ->
  s = util.inspect(process.versions).length
  s1 = 3333
  #process.memoryUsage().heapTotal;
  s2 = util.inspect(module.children).toString().length
  s3 = 4444
  #parseInt((Math.floor(Date.now()/1000) - process.hrtime()[0]).toString().replace(/[0-9]{1}$/,''));
  ((s | s3) + s + s3).toString() + s + s3

generateKey = (s, d) ->
  crypto.SHA256 generateKey.toString().length + Math.floor(d / tokenInterval).toString() + s

parseToken = (encToken) ->
  s = generateS()
  now = Date.now()
  f = now
  while f > now - loginInterval
    #console.log(f);
    token = null
    key = generateKey(s, f).toString()
    try
      token = crypto.Rabbit.decrypt(encToken, key).toString(crypto.enc.Utf8)
    catch e
    if token
      time = /\/([0-9]+)$/.exec(token)
      if time and (new Date).setTime(time[1]) > new Date
        s = null
        return token.replace('/' + time[1], '')
    f -= tokenInterval
  null

generateToken = (password) ->
  s = generateS()
  key = generateKey(s, Date.now()).toString()
  crypto.Rabbit.encrypt(password + '/' + (new Date).setTime((new Date).getTime() + loginInterval), key).toString()

checkPassword = (loggedInUser, loginCheck, userHash, done) ->
  decCheck = ''
  try
    decCheck = crypto.Rabbit.decrypt(loginCheck, loggedInUser.password).toString(crypto.enc.Utf8)
  catch e
  if decCheck.replace(/[0-9]+/gi, '') == 'rainstorm'
    done loggedInUser, userHash
  else
    console.log chalk.red.bold('bad password')
    done null, userHash

getLoggedInUser = (done) ->
  if fs.existsSync(appDataDir + '/settings.json')
    settings = loadSettings()
    loggedInUser = undefined
    for key of settings
      if settings[key].loginToken
        password = parseToken(settings[key].loginToken)
        if password
          loggedInUser = settings[key]
          settings[key].loginToken = generateToken(password)
          saveSettings settings
          loggedInUser.password = password
          if !loggedInUser.password
            inquirer.prompt [ {
              type: 'password'
              name: 'password'
              message: 'password'
            } ], (answers) ->
              loggedInUser.password = answers.password
              checkPassword loggedInUser, settings[key].loginCheck, key, done
          else
            return checkPassword(loggedInUser, settings[key].loginCheck, key, done)
      else
        #no login token
    if !loggedInUser
      settings[key].loginToken = undefined
      saveSettings settings
      return done(null, null)
  else
    console.log chalk.red.bold('no settings file, run ') + chalk.green.bold('rsafe setup') + chalk.red.bold(' to get going')
  return

getKey = (key, done) ->
  if !key
    inquirer.prompt [ {
      type: 'text'
      name: 'key'
      message: 'key'
    } ], (answers) ->
      done answers.key
      return
  else
    done key.replace('_all', '')
  return

getNewKey = (key, done) ->
  if !key
    inquirer.prompt [ {
      type: 'text'
      name: 'key'
      message: 'new key'
    } ], (answers) ->
      done answers.key
      return
  else
    done key
  return

getValue = (value, done) ->
  if !value
    inquirer.prompt [ {
      type: 'text'
      name: 'value'
      message: 'value'
    } ], (answers) ->
      done answers.value
      return
  else
    done value
  return

getUserName = (username, done) ->
  if !username
    inquirer.prompt [ {
      type: 'text'
      name: 'username'
      message: 'username'
    } ], (answers) ->
      done answers.username
      return
  else
    done username
  return

addPlugin = (user, userHash) ->
  settings = loadSettings()
  pluginChoices = []
  plugins.forEach (plugin) ->
    pluginChoices.push
      name: plugin.name
      checked: plugin.name == 'local' and !user.loginToken
    return
  inquirer.prompt [ {
    type: 'checkbox'
    name: 'plugins'
    message: 'choose storage plugins' + (if user.loginToken then ' to add' else '')
    choices: pluginChoices
  } ], (answers) ->
    userHash = userHash or crypto.MD5(user.username.toString()).toString()
    userPlugins = if settings[userHash] then settings[userHash].plugins else []
    pluginsToCall = []
    answers.plugins.forEach (pluginChoice) ->
      plugins.forEach (plugin) ->
        if plugin.name == pluginChoice
          pluginsToCall.push plugin.inquire
        return
      return
    result = pluginsToCall.reduce(q.when, q(
      userPlugins: userPlugins
      userHash: userHash
      password: user.password)).then(->
      settings[userHash] =
        loginCheck: generateLoginCheck(user.password)
        plugins: userPlugins
      saveSettings settings
      return
    )
    return
  return

if !fs.existsSync(appDataDir)
  fs.mkdirSync appDataDir
plugins = []
pluginfiles = glob.sync(path.normalize(__dirname) + '/plugins/*.js')
pluginfiles.forEach (plugin) ->
  plugins.push require(plugin)
  return
module.exports =
  setup: (argv, done) ->
    inquirer.prompt [
      {
        type: 'text'
        name: 'username'
        message: 'username'
      }
      {
        type: 'password'
        name: 'password'
        message: 'password'
      }
    ], addPlugin
    return
  login: (argv, done) ->
    if fs.existsSync(appDataDir + '/settings.json')
      settings = loadSettings()
      getUserName argv._[1], (username) ->
        userHash = crypto.MD5(username.toString()).toString()
        userSettings = settings[userHash]
        if userSettings
          inquirer.prompt [ {
            type: 'password'
            name: 'password'
            message: 'password'
          } ], (answers) ->
            checkPassword answers, userSettings.loginCheck, null, (user) ->
              if user
                userSettings.loginToken = generateToken(answers.password.toString())
              else
                userSettings.loginToken = undefined
              saveSettings settings
              if done
                return done(null, null)
              return
            return
        else
          console.log chalk.blue.bold('do i know you?')
          if done
            return done(null, null)
        return
    else
      console.log chalk.red.bold('no settings file, run ') + chalk.green.bold('rsafe setup') + chalk.red.bold(' to get going')
      if done
        return done(null, null)
    return
  logout: (argv, done) ->
    settings = loadSettings()
    loggedInUser = undefined
    for key of settings
      if settings[key].loginToken
        settings[key].loginToken = undefined
    saveSettings settings
    if done
      return done(null, null)
    return
  set: (argv, done) ->
    getLoggedInUser (user, userHash) ->
      if user
        getKey argv._[1], (key) ->
          if key
            getValue argv._[2], (value) ->

              callPlugin = (count) ->
                getPlugin(user.plugins[count]._type).set(key, value, user.plugins[count], user.password).then (data) ->
                  if data
                    data.__userHash = userHash
                    data.__plugins = user.plugins
                    user.plugins.forEach (plugin) ->
                      getPlugin(plugin._type).syncData data, plugin, user.password
                      return
                    if done
                      return done(null, null)
                  else
                    if count++ < user.plugins.length
                      callPlugin count
                  return
                return

              if value
                callPlugin 0
              else
                #no value
                if done
                  return done(null, null)
              return
          else
            #no key
            if done
              return done(null, null)
          return
      else
        #no user
        console.log chalk.blue.bold('please login')
        if done
          return done(null, null)
      return
    return
  remove: (argv, done) ->
    getLoggedInUser (user) ->
      if user
        getKey argv._[1], (key) ->

          callPlugin = (count) ->
            getPlugin(user.plugins[count]._type).remove(key, user.plugins[count], user.password, 'delete').then (data) ->
              if data
                user.plugins.forEach (plugin) ->
                  getPlugin(plugin._type).syncData data, plugin, user.password
                  return
                if done
                  return done(null, null)
              else
                if count++ < user.plugins.length
                  callPlugin count
              return
            return

          if key
            callPlugin 0
          else
            #no key
            if done
              return done(null, null)
          return
      else
        #no user
        console.log chalk.blue.bold('please login')
        if done
          return done(null, null)
      return
    return
  get: (argv, done) ->
    getLoggedInUser (user) ->
      if user
        getKey argv._[1], (key) ->

          callPlugin = (count) ->
            defer = q.defer()
            getPlugin(user.plugins[count]._type).get(key, user.plugins[count], user.password).then (value) ->
              if value
                defer.resolve value
              else if count++ < user.plugins.length
                defer.resolve callPlugin(count)
              else
                defer.reject null
              return
            defer.promise

          if key
            #loop through plugins and get the first good value
            callPlugin(0).then ((value) ->
              cp.copy value
              console.log chalk.white.bold('copied to clipboard')
              if done
                return done(null, null)
              return
            ), (err) ->
              console.log chalk.red.bold('could not find key')
              if done
                return done(null, null)
              return
          else
            #no key
            if done
              return done(null, null)
          return
      else
        #no user
        console.log chalk.blue.bold('please login')
        if done
          return done(null, null)
      return
    return
  rename: (argv, done) ->
    getLoggedInUser (user, userHash) ->
      if user
        getKey argv._[1], (key) ->
          getNewKey argv._[2], (newKey) ->

            callPlugin = (count) ->
              defer = q.defer()
              rplugin = getPlugin(user.plugins[count]._type)
              rplugin.getObject(key, user.plugins[count], user.password).then (value) ->
                if value
                  rplugin.remove(key, user.plugins[count], user.password, 'rename').then ->
                    rplugin.setObject(newKey, value, user.plugins[count], user.password).then (data) ->
                      if data
                        data.__userHash = userHash
                        data.__plugins = user.plugins
                        user.plugins.forEach (plugin) ->
                          getPlugin(plugin._type).syncData data, plugin, user.password
                          return
                      process.nextTick ->
                        defer.resolve()
                        return
                      return
                    return
                else if count++ < user.plugins.length
                  defer.resolve callPlugin(count)
                else
                  defer.reject null
                return
              defer.promise

            if key
              #loop through plugins and get the first good value
              callPlugin(0).then (->
                console.log chalk.white.bold('key successfully renamed')
                if done
                  return done(null, null)
                return
              ), (err) ->
                console.log chalk.red.bold('could not find key')
                if done
                  return done(null, null)
                return
            else
              #no key
              if done
                return done(null, null)
            return
          return
      else
        #no user
        console.log chalk.blue.bold('please login')
        if done
          return done(null, null)
      return
    return
  list: (argv, done) ->
    getLoggedInUser (user) ->
      if user
        getKey argv._[1], (key) ->

          callPlugin = (count) ->
            defer = q.defer()
            getPlugin(user.plugins[count]._type).list(key, user.plugins[count], user.password).then (list) ->
              if list
                defer.resolve list
              else if count++ < user.plugins.length
                defer.resolve callPlugin(count)
              else
                defer.reject null
              return
            defer.promise

          callPlugin(0).then (list) ->
            done null, _.sortBy(list)
            return
          return
      else
        #no user
        console.log chalk.blue.bold('please login')
        if done
          return done(null, null)
      return
    return
  add: (argv, done) ->
    if argv._.indexOf('plugin') == 1
      getLoggedInUser (user, userHash) ->
        if user
          addPlugin user, userHash
        else
          console.log chalk.blue.bold('please login')
          if done
            return done(null, null)
        return
    return
  password: (argv, done) ->
    getLoggedInUser (user, userHash) ->
      if user
        inquirer.prompt [
          {
            type: 'password'
            name: 'oldPassword'
            message: 'old password'
          }
          {
            type: 'password'
            name: 'newPassword'
            message: 'new password'
          }
          {
            type: 'password'
            name: 'passwordMatch'
            message: 'type it again'
          }
        ], (answers) ->
          #get settings

          callPlugin = (count) ->
            settings = loadSettings()
            getPlugin(user.plugins[count]._type).getData(user.plugins[count], answers.oldPassword).then (data) ->
              if data
                #rewrite all plugin properties
                newPlugins = []
                user.plugins.forEach (plugin) ->
                  for key of plugin
                    if key.indexOf('_') == 0
                      f -= tokenInterval
                      continue
                    try
                      decProp = crypto.Rabbit.decrypt(plugin[key], answers.oldPassword).toString(crypto.enc.Utf8)
                      plugin[key] = crypto.Rabbit.encrypt(decProp, answers.newPassword).toString()
                    catch e
                  newPlugins.push plugin
                  return
                settings[userHash].plugins = newPlugins
                settings[userHash].loginCheck = generateLoginCheck(answers.newPassword)
                saveSettings settings
                #rewrite data
                data.__userHash = userHash
                data.__plugins = user.newPlugins
                settings[userHash].plugins.forEach (plugin) ->
                  getPlugin(plugin._type).syncData data, plugin, answers.newPassword
                  return
                if done
                  return done(null, null)
              else
                if count++ < user.plugins.length
                  callPlugin count
              return
            return

          user.password = answers.oldPassword
          checkPassword user, user.loginCheck, null, (user) ->
            if user
              if answers.newPassword == answers.passwordMatch
                callPlugin 0
              else
                console.log 'passwords must match'
                if done
                  return done(null, null)
            return
          return
      return
    return
  username: (argv, done) ->
    getLoggedInUser (user, userHash) ->
      if user
        inquirer.prompt [
          {
            type: 'text'
            name: 'oldUsername'
            message: 'old username'
          }
          {
            type: 'text'
            name: 'newUsername'
            message: 'new username'
          }
        ], (answers) ->
          settings = loadSettings()
          settings[userHash] = undefined
          newHash = crypto.MD5(answers.newUsername).toString()
          if !settings[newHash]
            user.password = undefined
            settings[newHash] = user
            saveSettings settings
          if done
            return done(null, null)
          return
      return
    return
  help: (argv, done) ->
    console.log ''
    console.log chalk.yellow.bold('available commands')
    console.log ''
    console.log chalk.green.bold('setup') + ' - get started'
    console.log chalk.green.bold('login')
    console.log chalk.green.bold('logout')
    console.log chalk.green.bold('set') + ' - set data'
    console.log chalk.green.bold('get') + ' - get data'
    console.log chalk.green.bold('list') + ' - list keys'
    console.log chalk.green.bold('remove') + ' - delete key and data'
    console.log chalk.green.bold('rename') + ' - rename a key'
    console.log chalk.green.bold('add plugin') + ' - add a storage plugin'
    console.log chalk.green.bold('username') + ' - change your local username'
    console.log chalk.green.bold('password') + ' - change your password'
    console.log chalk.green.bold('help') + ' - this list of commands'
    console.log ''
    if done
      done null, null
    return

# ---
# generated by js2coffee 2.1.0