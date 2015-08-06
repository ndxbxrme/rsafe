getData = (settings, password, done) ->
  url = crypto.Rabbit.decrypt(settings.url, password).toString(crypto.enc.Utf8)
  if fs.existsSync(url)
    file = fs.readFileSync(url)
    try
      data = crypto.Rabbit.decrypt(fs.readFileSync(url).toString(), password).toString(crypto.enc.Utf8)
      return done(JSON.parse(data))
    catch e
      return done({})
  else
    return done({})
  return

saveData = (settings, password, data) ->
  url = crypto.Rabbit.decrypt(settings.url, password).toString(crypto.enc.Utf8)
  fs.writeFileSync url, crypto.Rabbit.encrypt(JSON.stringify(data), password).toString()
  return

'use strict'
inquirer = require('inquirer')
q = require('q')
fs = require('fs')
crypto = require('crypto-js')
common = require('../common')
chalk = require('chalk')
appDataDir = (process.env.APPDATA or (if process.platform == 'darwin' then process.env.HOME + 'Library/Preference' else '/var/local')) + '/rsafe'
module.exports =
  name: 'local'
  inquire: (bundle) ->
    console.log chalk.yellow.bold('\nlocal storage setup\n')
    defer = q.defer()
    inquirer.prompt [
      {
        type: 'text'
        name: 'url'
        message: 'storage location (' + appDataDir + ')'
      }
      {
        type: 'text'
        name: 'name'
        message: 'give this safe a name'
      }
    ], (answers) ->
      url = crypto.Rabbit.encrypt(answers.url or appDataDir + '/safe' + bundle.userHash + '.json', bundle.password).toString()
      name = crypto.Rabbit.encrypt(answers.url or 'local', bundle.password).toString()
      settings = 
        _type: 'local'
        name: name
        url: url
      getData settings, bundle.password, (data) ->
        saveData settings, bundle.password, data
        bundle.userPlugins.unshift settings
        #only local should unshift(), everyone else should push()
        defer.resolve bundle
        return
      return
    defer.promise
  remove: (key, settings, password, confirm) ->
    defer = q.defer()
    getData settings, password, (data) ->
      inquirer.prompt [ {
        type: 'text'
        name: 'confirm'
        message: 'type ' + confirm + ' to continue'
      } ], (answers) ->
        if answers.confirm == confirm
          data = common.remove(key, data)
          saveData settings, password, data
          defer.resolve data
        else
          defer.reject null
        return
      return
    defer.promise
  set: (key, value, settings, password) ->
    defer = q.defer()
    getData settings, password, (data) ->
      data = common.set(key, value, data)
      defer.resolve data
      return
    defer.promise
  setObject: (key, value, settings, password) ->
    defer = q.defer()
    getData settings, password, (data) ->
      data = common.setObject(key, value, data)
      defer.resolve data
      return
    defer.promise
  get: (key, settings, password) ->
    defer = q.defer()
    getData settings, password, (data) ->
      common.get key, data, defer
      return
    defer.promise
  getObject: (key, settings, password) ->
    defer = q.defer()
    getData settings, password, (data) ->
      common.getObject key, data, defer
      return
    defer.promise
  list: (key, settings, password) ->
    defer = q.defer()
    getData settings, password, (data) ->
      common.list key, data, defer
      return
    defer.promise
  syncData: (data, settings, password) ->
    saveData settings, password, data
    return
  getData: (settings, password) ->
    defer = q.defer()
    getData settings, password, (data) ->
      if data
        defer.resolve data
      else
        defer.reject null
      return
    defer.promise
