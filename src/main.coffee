'use strict'

electron = require 'electron'
{app, BrowserWindow, globalShortcut, Tray, Menu, ipcMain, Notification, clipboard} = electron
{autoUpdater} = require 'electron-updater'
fs = require 'fs'
url = require 'url'
path = require 'path'
robot = require 'robotjs'
ioHook = require 'iohook'
dotty = require 'dotty'
async = require 'async'
jpeg = require 'jpeg-js'
request = require 'request'
stream = require 'stream'
bufferSlice = require 'buffer-slice'
Gists = require 'gists'
{packer, encryptor} = require './out.js'
appDataDir = app.getPath 'userData'
data = null
lastUpdated = 0
password = null
username = null
cleanUsername = null
shiftDown = false
capturing = false
setting = false
noAsterix = 0 #oh the gaul
captured = ''
currentKey = ''
mainWindow = null
feedbackWindow = null
inQuotes = false
tray = null
dataUpdated = false
contextMenu = null
settings = {}
mysettings = null
width = 0
height = 0
plugins = 
  local:
    get: (name, bufCount, callback) ->
      myurl = path.join(appDataDir, cleanUsername, "#{name}#{if bufCount then bufCount else ''}.png")
      fs.exists myurl, (exists) ->
        if exists
          rs = fs.createReadStream myurl
          packer.readBuffer rs, (err, buffer, dateVal, isLast) ->
            callback null, buffer, dateVal, isLast
        else
          callback 'no file', null
    set: (name, buffer, imgData, imgWidth, dateVal, bufCount, isLast, callback) ->
      dataDir = path.join appDataDir, cleanUsername
      fs.exists dataDir, (exists) ->
        if not exists
          fs.mkdirSync dataDir
        ws = fs.createWriteStream path.join(dataDir, "#{name}#{if bufCount then bufCount else ''}.png")
        packer.writeBuffer ws, buffer, imgData, imgWidth, dateVal, isLast, callback
  github:
    get: (name, bufCount, callback) ->
      if not mysettings.githubUser or not mysettings.githubKey
        return callback 'no github'
      gists = new Gists
        token: mysettings.githubKey
      gists.all user:mysettings.githubUser, (err, res) ->
        if not err
          gistid = null
          for gist in res
            if gist.description is 'rpics'
              gistid = gist.id
              break
          if gistid
            gists.download
              id: gistid
            , (err, res) ->
              if not err
                filename = "#{name}#{if bufCount then bufCount else ''}.png"
                buf = Buffer.from res.files[filename].content.replace('data:image/png;base64,', ''), 'base64'
                rs = new stream.Readable()
                rs._read = ->
                rs.push buf
                rs.push null
                packer.readBuffer rs, (err, buffer, dateVal, isLast) ->
                  callback null, buffer, dateVal, isLast
              else
                callback 'file error'
          else
            callback 'gist download error'
        else
          callback 'gist list error'
    set: (name, buffer, imgData, imgWidth, dateVal, bufCount, isLast, callback) ->
      if not mysettings.githubUser or not mysettings.githubKey
        return callback 'no github'
      buf = new Buffer []
      s = new stream.Writable()
      s._read = ->
      s._write = (chunk, encoding, next) ->
        buf = Buffer.concat [buf, chunk]
        next()
      s.on 'data', (chunk) ->
      s.end = ->
        myfile = {}
        filename = "#{name}#{if bufCount then bufCount else ''}.png"
        myfile[filename] = 
          content: 'data:image/png;base64,' + buf.toString 'base64'
        gists = new Gists
          token: mysettings.githubKey
        gists.all user:mysettings.githubUser, (err, res) ->
          if not err
            gistid = null
            for gist in res
              if gist.description is 'rpics'
                gistid = gist.id
                break
            if not gistid
              gists.create
                description: 'rpics'
                public: true
                files: myfile
              , callback
            else
              gists.edit
                id: gistid
                description: 'rpics'
                public: true
                files: myfile
              , callback
          else
            callback err
      packer.writeBuffer s, buffer, imgData, imgWidth, dateVal, isLast, ->
doGetData = (plugin, callback) ->
  buffer = new Buffer []
  isLast = false
  count = 0
  lastUpdated = 0
  async.until ->
    isLast
  , (untilCallback) ->
    plugins[plugin].get 'pic', count++, (err, encrypted, dateVal, _isLast) ->
      if not err
        isLast = _isLast
        lastUpdated = dateVal
        buffer = Buffer.concat [buffer, encrypted]
      untilCallback err
  , (err) ->
    if not err
      encryptor.decrypt buffer, null, (err, text) ->
        mydata = JSON.parse text
        callback null,
          date: lastUpdated
          data: mydata
    else
      callback err
doSaveData = (plugin, dateVal, callback) ->
  text = JSON.stringify data
  encryptor.encrypt text, null, (err, buffer) ->
    if not err
      buffers = bufferSlice buffer, 360000
      bufCount = 0
      async.eachSeries buffers, (buf, bufCallback) ->
        dataLen = Math.ceil(buf.length * 4 / 3 * 4) + 12
        imgWidth = Math.round(Math.ceil(Math.sqrt dataLen) / 10) * 10
        request.get
          url: "https://picsum.photos/#{imgWidth}/#{imgWidth}"
          encoding: null
        , (err, response, body) ->
          rawImageData = jpeg.decode body
          plugins[plugin].set 'pic', buf, rawImageData.data, imgWidth, dateVal, bufCount, ((bufCount + 1) is buffers.length), ->
            bufCount++
            bufCallback()
      , ->
        dataUpdated = false
        callback err
    else
      globalError = err
      callback err
getData = (callback) ->
  dateVal = 0
  updateList = {}
  async.eachSeries Object.keys(plugins), (plugin, pluginCallback) ->
    doGetData plugin, (err, res) ->
      if not err
        if res.date > dateVal
          dateVal = res.date
          data = res.data
        updateList[plugin] = res.date
      pluginCallback()
  , ->
    async.eachSeries Object.keys(updateList), (plugin, updateCallback) ->
      if updateList[plugin] < dateVal
        doSaveData plugin, dateVal, updateCallback
      else
        updateCallback()
    , ->
      callback()
saveData = (callback) ->
  dateVal = new Date().valueOf()
  async.eachSeries Object.keys(plugins), (plugin, pluginCallback) ->
    doSaveData plugin, dateVal, pluginCallback
  , ->
    callback()
loadSettings = ->
  uri = path.join appDataDir, 'settings.json'
  fs.exists uri, (exists) ->
    if exists
      settings = JSON.parse fs.readFileSync uri, 'utf-8'
    else
      console.log 'could not load settings'
saveSettings = ->
  uri = path.join appDataDir, 'settings.json'
  fs.writeFile uri, JSON.stringify(settings), 'utf-8'
goto = (url) ->
  mainWindow.webContents.send 'goto', url
logIn = ->
  mainWindow.setSize 400, 200
  mainWindow.setPosition width - 400 - 10, height - 200 - 10
  goto '/'
  mainWindow.show()
  contextMenu.getMenuItemById('login').visible = true
  contextMenu.getMenuItemById('setkey').visible = false
  contextMenu.getMenuItemById('getkey').visible = false
  contextMenu.getMenuItemById('logout').visible = false
  contextMenu.getMenuItemById('prefs').visible = false
logOut = ->
  encryptor.setPassword null
  username = null
  cleanUsername = null
  password = null
  data = null
  contextMenu.getMenuItemById('login').visible = true
  contextMenu.getMenuItemById('logout').visible = false
  contextMenu.getMenuItemById('setkey').visible = false
  contextMenu.getMenuItemById('getkey').visible = false
  contextMenu.getMenuItemById('prefs').visible = false
showSetKey = ->
  mainWindow.setSize 400, 200
  mainWindow.setPosition width - 400 - 10, height - 200 - 10
  goto '/setkey'
  mainWindow.show()
showGetKey = ->
  mainWindow.setSize 400, 200
  mainWindow.setPosition width - 400 - 10, height - 200 - 10
  goto '/getKey'
  mainWindow.show()
showPrefs = ->
  mainWindow.setSize 400, 200
  mainWindow.setPosition width - 400 - 10, height - 200 - 10
  goto '/prefs'
  mainWindow.show()
  

 
ready = ->
  loadSettings()
  tray = new Tray path.join __dirname, 'icon.png'
  contextMenu = Menu.buildFromTemplate [
    id: 'login'
    label: 'Log in'
    click: logIn
  , 
    id: 'logout'
    label: 'Log out'
    click: logOut
    hide: true
  ,
    id: 'setkey'
    label: 'Set key'
    click: showSetKey
    hide: true
  ,
    id: 'getkey'
    label: 'Get key'
    click: showGetKey
    hide: true
  ,
    id: 'prefs'
    label: 'Preferences'
    click: showPrefs
    hide: true
  ,
    label: 'Quit'
    click: ->
      app.quit()
  ]
  tray.setToolTip 'rSafe'
  tray.setContextMenu contextMenu
  autoUpdater.checkForUpdatesAndNotify()
  {width, height} = electron.screen.getPrimaryDisplay().workAreaSize
  mainWindow = new BrowserWindow
    x: width - 400 - 10
    y: height - 200 - 10
    width: 400
    height: 200
    frame: false
    autoHideMenuBar: true
    show: false
  BrowserWindow.addDevToolsExtension 'd:/DEV/temp/26/yma-inspector/'
  mainWindow.loadURL url.format
    pathname: path.join __dirname, 'index.html'
    protocol: 'file:'
    slashes: true
  #mainWindow.openDevTools()
  mainWindow.on 'closed', ->
    mainWindow = null
  feedbackWindow = new BrowserWindow
    x: width - 400 - 10
    y: height - 78 - 10
    width: 400
    height: 78
    frame: false
    autoHideMenuBar: true
    alwaysOnTop: true
    transparent: true
    show: false
    focusable: false
  feedbackWindow.loadURL url.format
    pathname: path.join __dirname, 'feedback.html'
    protocol: 'file:'
    slashes: true
  #feedbackWindow.openDevTools()
  session = electron.session
  session.defaultSession.webRequest.onBeforeRequest ['*://*./*'], (details, cb) ->
    myurl = details.url.replace /^file:\/\/\/.:\//, ''
    root = (myurl.match(/([^\/]+)/) or [])[0]
    switch root
      when 'app'
        cb
          cancel: false
          redirectURL: url.format 
            pathname: path.join __dirname, '..', myurl
            protocol: 'file:'
            slashes: true
      else
        cb
          cancel: false
  
  ioHook.on 'keypress', keyDown
  logIn()
  #ioHook.on 'keyup', keyUp
  ioHook.start()
  ipcMain.on 'login', (win, response) ->
    if response.username and response.password
      username = response.username
      cleanUsername = username.replace /[^\w]+/g, '_'
      password = response.password
      encryptor.setPassword password
      if settings[username]
        buffer = Buffer.from settings[username], 'utf-8'
        encryptor.decrypt buffer, null, (err, decrypted) ->
          mysettings = JSON.parse decrypted
      getData (err) ->
        if err
          data = {}
        if data or lastUpdated is 0
          notification = new Notification
            title: 'rSafe'
            body: 'Logged in as ' + username
          notification.show()
          mainWindow.hide()
          contextMenu.getMenuItemById('login').visible = false
          contextMenu.getMenuItemById('logout').visible = true
          contextMenu.getMenuItemById('setkey').visible = true
          contextMenu.getMenuItemById('getkey').visible = true
          contextMenu.getMenuItemById('prefs').visible = true
          #showSetKey()
          #get latest data from github
        else
          notification = new Notification
            title: 'rSafe'
            body: 'Login error'
          notification.show()
    else
      notification = new Notification
        title: 'rSafe'
        body: 'Login error'
      notification.show()
  ipcMain.on 'setKey', (win, response) ->
    data = data or {}
    capturing = false
    setting = false
    captured = ''
    currentKey = ''
    if response.key and response.val
      dotty.put data, "#{response.key}._value", response.val
      dataUpdated = true
      saveData (err) ->
        if not err
          notification = new Notification
            title: 'rSafe'
            body: 'Success'
          notification.show()
          mainWindow.hide()
  ipcMain.on 'setPrefs', (win, response) ->
    mysettings = response
    encryptor.encrypt JSON.stringify(response), null, (err, encrypted) ->
      settings[username] = encrypted
      saveSettings()
      getData ->
      mainWindow.hide()
  ipcMain.on 'getPrefs', (win, response) ->
    mainWindow.webContents.send 'prefs', mysettings
  ipcMain.on 'hideWindow', (win) ->
    mainWindow.hide()
app.on 'ready', ready
app.on 'window-all-closed', ->
  process.platform is 'darwin' or app.quit()
app.on 'will-quit', ->
  tray.destroy()
  ioHook.stop()
app.on 'activiate', ->
  mainWindow or ready()
keynote = null
keyDown = (event) ->
  if cleanUsername and password
    keychar = String.fromCharCode event.keychar
    if not capturing and not setting
      if keychar is '*'
        if ++noAsterix > 1
          capturing = true
          noAsterix = 0
          feedbackWindow.webContents.send 'setText', 'rsafe'
          feedbackWindow.showInactive()
          ###
          keynote = new Notification
            title: 'rSafe'
            body: 'capturing'
          keynote.show()
          ###
      else
        noAsterix = 0
    else
      if keychar is '\b'
        captured = captured.substr 0, captured.length - 1
        feedbackWindow.webContents.send 'setText', captured
        if captured.length is 0
          capturing = false
          feedbackWindow.hide()
      else if event.keychar is 27
        captured = ''
        capturing = ''
        setting = false
        currentKey = ''
        feedbackWindow.hide()
      else if keychar is '='
        currentKey = captured
        captured = ''
        capturing = false
        setting = true
      else if setting and keychar is '"'
        inQuotes = not inQuotes
      else if keychar is ' ' and not inQuotes
        if setting
          feedbackWindow.hide()
          if password
            dataUpdated = true
            data = data or {}
            if captured is 'clip'
              captured = clipboard.readText()
            dotty.put data, "#{currentKey}._value", captured
            saveData (err) ->
              if not err
                feedbackWindow.hide()
                notification = new Notification
                  title: 'rSafe'
                  body: 'Success'
                notification.show()
          else
            notification = new Notification
              title: 'rSafe'
              body: 'Not logged in'
            notification.show()
          currentKey = ''
          setting = false
        else
          feedbackWindow.hide()
          if copy = /&copy$/.test captured
            captured = captured.replace(/&copy$/, '')
          val = dotty.get data, "#{captured}._value"
          if val
            i = 0
            while i++ < captured.length + 3 + (if copy then 5 else 0)
              robot.keyTap 'backspace'
            if copy
              clipboard.writeText val
            else
              robot.typeString val
        captured = ''
        capturing = false
      else
        captured += keychar
        feedbackWindow.webContents.send 'setText', captured
keyUp = (event) ->
  if event.rawcode is 160
    shiftDown = false