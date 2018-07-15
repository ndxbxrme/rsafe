'use strict'
yma = require 'yma'
{ipcRenderer} = require 'electron'

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