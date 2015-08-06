getData = (settings, password, done) ->
  token = crypto.Rabbit.decrypt(settings.token, password).toString(crypto.enc.Utf8)
  gistUrl = crypto.Rabbit.decrypt(settings.gistUrl, password).toString(crypto.enc.Utf8)
  if !client
    client = new Client(token: token)
  client.get '/' + gistUrl, (error, gist) ->
    if error
      return done({})
    if gist.files and gist.files.length
      try
        data = crypto.Rabbit.decrypt(gist.files[0].content, password).toString(crypto.enc.Utf8)
        return done(JSON.parse(data))
      catch e
        return done({})
    else
      return done({})
    return
  return

saveData = (settings, password, data) ->
  token = crypto.Rabbit.decrypt(settings.token, password).toString(crypto.enc.Utf8)
  gistUrl = crypto.Rabbit.decrypt(settings.gistUrl, password).toString(crypto.enc.Utf8)
  gistUrl = gistUrl.replace('https://api.github.com/gists/', '')
  if !client
    client = new Client(token: token)
  gist = 
    'public': false
    files: 'rsafe.txt': content: crypto.Rabbit.encrypt(JSON.stringify(data), password).toString()
  client.patch '/' + gistUrl, gist, (error, g) ->
    #do nothing
    return
  return

'use strict'
inquirer = require('inquirer')
q = require('q')
fs = require('fs')
crypto = require('crypto-js')
common = require('../common')
chalk = require('chalk')
Client = require('node-gist').Client
client = undefined
module.exports =
  name: 'github'
  inquire: (bundle) ->
    console.log chalk.yellow.bold('\nGithub Gist storage setup\n')
    defer = q.defer()
    inquirer.prompt [
      {
        type: 'text'
        name: 'user'
        message: 'Github username'
      }
      {
        type: 'password'
        name: 'password'
        message: 'Github password'
      }
    ], (answers) ->
      client = new Client(
        user: answers.user
        password: answers.password
        token: undefined)
      client.path = ''
      authorization = 
        scopes: [ 'gist' ]
        note: 'rsafe'
        note_url: 'https://github.com/ndxbxrme/rsafe'
      client.post '/authorizations', authorization, (error, data) ->
        if error
          throw new Error error
        if !data.token
          throw new Error 'Github login failed'
        token = crypto.Rabbit.encrypt(data.token, bundle.password).toString()
        settings = 
          _type: 'github'
          name: 'github'
          token: token
        gist = 
          'public': false
          files: 'rsafe.txt': content: crypto.Rabbit.encrypt(JSON.stringify({}), bundle.password).toString()
        client = new Client(token: data.token)
        client.post '', gist, (error, g) ->
          if error
            throw new Error error
          if g.message
            throw new Error g.message
          settings.gistUrl = crypto.Rabbit.encrypt(g.url, bundle.password).toString()
          bundle.userPlugins.push settings
          defer.resolve bundle
          return
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
