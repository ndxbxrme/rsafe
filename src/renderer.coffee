glob = require 'glob'
path = require 'path'
yma = require 'yma'
{ipcRenderer} = require 'electron'
console.log 'hey'

glob.sync('./app/routes/**/*.js').forEach (file) ->
  console.log 'loading', file
  require path.resolve file
  
ipcRenderer.on 'goto', (sender, url) ->
  console.log 'got a goto', url
  yma.goto url