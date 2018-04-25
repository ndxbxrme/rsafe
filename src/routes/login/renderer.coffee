'use strict'

{ipcRenderer} = require 'electron'

module.exports = 
  submit: (e) ->
    e.preventDefault()
    ipcRenderer.send 'login',
      username: document.getElementsByName('username')[0].value
      password: document.getElementsByName('password')[0].value
    console.log 'submitted'