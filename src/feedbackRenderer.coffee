'use strict'
{ipcRenderer} = require 'electron'

ipcRenderer.on 'setText', (win, text) ->
  document.querySelector 'h3'
  .innerText = text
