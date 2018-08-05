'use strict'
yma = require 'yma'
{ipcRenderer} = require 'electron'

yma.route '/', ->
  templateUrl: 'app/routes/list/list.html'
  controller: ->
    @.submit = (e) =>
      e.preventDefault()
      ipcRenderer.send 'login',
        username: @.username
        password: @.password
    ->
      document.querySelector('[model=username]').focus()