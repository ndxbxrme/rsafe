'use strict'
yma = require 'yma'
{ipcRenderer} = require 'electron'

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