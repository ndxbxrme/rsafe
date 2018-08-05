glob = require 'glob'
path = require 'path'
yma = require 'yma'
{ipcRenderer} = require 'electron'
console.log 'hey'

yma.route '/', ->
  templateUrl: 'app/routes/login/login.html'
  controller: ->
    @.submit = (e) =>
      e.preventDefault()
      ipcRenderer.send 'login',
        username: @.username
        password: @.password
    ->
      document.querySelector('[model=username]').focus()
yma.route '/prefs', ->
  templateUrl: '/app/routes/prefs/prefs.html'
  controller: ->
    ipcRenderer.send 'getPrefs'
    ipcRenderer.on 'prefs', (thing, data) =>
      console.log 'got prefs', data, @
      @.githubUser = data.githubUser
      @.githubKey = data.githubKey
      #@.$update()
    @.submit = (e) =>
      ipcRenderer.send 'setPrefs',
        githubUser: @.githubUser
        githubKey: @.githubKey
    null
yma.route '/setkey', ->
  templateUrl: 'app/routes/setkey/setkey.html'
  controller: ->
    @.submit = =>
      console.log 'shout', @.key, @.val
      ipcRenderer.send 'setKey',
        key: @.key
        val: @.val
      ###
      console.log 'submitting'
      e.preventDefault()
      ipcRenderer.send 'setKey',
        key: @.key
        val: @.val
      ###
    @.cancel = ->
      ipcRenderer.send 'hideWindow'
    null
  
ipcRenderer.on 'goto', (sender, url) ->
  console.log 'got a goto', url
  yma.goto url