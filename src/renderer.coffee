glob = require 'glob'
path = require 'path'
yma = require 'yma'
{ipcRenderer} = require 'electron'
console.log 'hey'

require './app/routes/login.js'
require './app/routes/prefs.js'
require './app/routes/setkey.js'
  
ipcRenderer.on 'goto', (sender, url) ->
  console.log 'got a goto', url
  yma.goto url