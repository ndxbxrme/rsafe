'use strict'
yma = require 'yma'
{ipcRenderer} = require 'electron'

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
