'use strict'

{ipcRenderer} = require 'electron'

module.exports =
  submit: (e) ->
    e.preventDefault()
    ipcRenderer.send 'setKey',
      key: document.getElementsByName('key')[0].value
      val: document.getElementsByName('val')[0].value
  cancel: ->
    ipcRenderer.send 'hideWindow'