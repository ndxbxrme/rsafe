getData = (settings, password, done) ->
  url = crypto.Rabbit.decrypt(settings.url, password).toString(crypto.enc.Utf8)
  hash = settings._hash
  mongoUsername = crypto.Rabbit.decrypt(settings.username, password).toString(crypto.enc.Utf8)
  mongoPassword = crypto.Rabbit.decrypt(settings.password, password).toString(crypto.enc.Utf8)
  mongoose.connect url, (err) ->
    Data.findOne(_hash: hash).exec (err, data) ->
      mongoose.connection.close()
      try
        output = crypto.Rabbit.decrypt(data.data, password).toString(crypto.enc.Utf8)
        return done(JSON.parse(output))
      catch e
        return done({})
      done {}
    return
  return

saveData = (settings, password, data) ->
  url = crypto.Rabbit.decrypt(settings.url, password).toString(crypto.enc.Utf8)
  hash = settings._hash
  mongoUsername = crypto.Rabbit.decrypt(settings.username, password).toString(crypto.enc.Utf8)
  mongoPassword = crypto.Rabbit.decrypt(settings.password, password).toString(crypto.enc.Utf8)
  mongoose.connect url, (err) ->
    Data.findOne(_hash: hash).exec (err, dbdata) ->
      if dbdata
        dbdata.data = crypto.Rabbit.encrypt(JSON.stringify(data), password).toString()
        dbdata.save (err) ->
          mongoose.connection.close()
          return
      else
        newData = new Data
        newData._hash = hash
        newData.data = crypto.Rabbit.encrypt(JSON.stringify(data), password).toString()
        newData.save (err) ->
          mongoose.connection.close()
          return
      return
    return
  return

'use strict'
inquirer = require('inquirer')
q = require('q')
mongoose = require('mongoose')
crypto = require('crypto-js')
common = require('../common')
chalk = require('chalk')
userHash = ''
dataSchema = mongoose.Schema(
  _hash: String
  data: String)
Data = mongoose.model('Data', dataSchema)
module.exports =
  name: 'mongodb'
  inquire: (bundle) ->
    console.log chalk.yellow.bold('\nmongodb storage setup\n')
    defer = q.defer()
    inquirer.prompt [
      {
        type: 'text'
        name: 'url'
        message: 'mongodb url (leave blank for default)'
      }
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
      {
        type: 'text'
        name: 'name'
        message: 'give this safe a name'
      }
    ], (answers) ->
      url = crypto.Rabbit.encrypt(answers.url or 'mongodb://localhost:27017/rsafe', bundle.password).toString()
      name = crypto.Rabbit.encrypt(answers.name or 'mongo', bundle.password).toString()
      mongoUsername = crypto.Rabbit.encrypt(answers.username.toString(), bundle.password).toString()
      mongoPassword = crypto.Rabbit.encrypt(answers.password.toString(), bundle.password).toString()
      settings = 
        _type: 'mongodb'
        name: name
        url: url
        _hash: bundle.userHash
        username: mongoUsername
        password: mongoPassword
      getData settings, bundle.password, (data) ->
        saveData settings, bundle.password, data
        bundle.userPlugins.push settings
        #only local should unshift(), other plugins should push()
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
