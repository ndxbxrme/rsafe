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
bufferSlice = require 'buffer-slice'
{packer, encryptor} = require './out.js'
appDataDir = (process.env.APPDATA or (if process.platform == 'darwin' then process.env.HOME + 'Library/Preference' else '/var/local')) + '/rsafe'
data = null
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
inQuotes = false
tray = null
dataUpdated = false
contextMenu = null
width = 0
height = 0
local =
  get: (name, bufCount, callback) ->
    myurl = path.join(appDataDir, cleanUsername, "#{name}#{if bufCount then bufCount else ''}.png")
    fs.exists myurl, (exists) ->
      if exists
        rs = fs.createReadStream myurl
        packer.readBuffer rs, (err, buffer, dateVal, isLast) ->
          callback null, buffer, dateVal, isLast
      else
        callback 'no file', null
  set: (name, buffer, imgData, width, dateVal, bufCount, isLast, callback) ->
    dataDir = path.join appDataDir, cleanUsername
    fs.exists dataDir, (exists) ->
      if not exists
        fs.mkdirSync dataDir
      ws = fs.createWriteStream path.join(dataDir, "#{name}#{if bufCount then bufCount else ''}.png")
      packer.writeBuffer ws, buffer, imgData, width, dateVal, isLast, callback
getData = (callback) ->
  if not data
    buffer = new Buffer []
    isLast = false
    count = 0
    async.until ->
      isLast
    , (untilCallback) ->
      local.get 'pic', count++, (err, encrypted, dateVal, _isLast) ->
        #console.log 'err', err, 'enc', encrypted
        if not err
          isLast = _isLast
          buffer = Buffer.concat [buffer, encrypted]
        untilCallback err
    , (err) ->
      if not err
        encryptor.decrypt buffer, null, (err, text) ->
          data = JSON.parse text
          callback()
      else
        callback err
  else
    callback()
saveData = (callback) ->
  console.log 'saving data'
  if dataUpdated
    text = JSON.stringify data
    encryptor.encrypt text, null, (err, buffer) ->
      if not err
        buffers = bufferSlice buffer, 360000
        bufCount = 0
        async.eachSeries buffers, (buf, bufCallback) ->
          dataLen = Math.ceil(buf.length * 4 / 3 * 4) + 12
          width = Math.round(Math.ceil(Math.sqrt dataLen) / 10) * 10
          console.log 'about to fetch image'
          request.get
            url: "https://placeimg.com/#{width}/#{width}/all"
            encoding: null
          , (err, response, body) ->
            console.log 'got image', err
            rawImageData = jpeg.decode body
            dateVal = new Date().valueOf()
            local.set 'pic', buf, rawImageData.data, width, dateVal, bufCount, ((bufCount + 1) is buffers.length), ->
              bufCount++
              bufCallback()
        , ->
          dataUpdated = false
          callback err
      else
        globalError = err
        callback err
  else
    callback null
    
logIn = ->
  mainWindow.setSize 400, 200
  mainWindow.setPosition width - 400 - 10, height - 200 - 10
  mainWindow.loadURL url.format
    pathname: path.join __dirname, 'routes/login/login.html'
    protocol: 'file:'
    slashes: true
  mainWindow.show()
  contextMenu.getMenuItemById('login').visible = true
  contextMenu.getMenuItemById('setkey').visible = false
  contextMenu.getMenuItemById('getkey').visible = false
  contextMenu.getMenuItemById('logout').visible = false
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
showSetKey = ->
  mainWindow.setSize 400, 200
  mainWindow.setPosition width - 400 - 10, height - 200 - 10
  mainWindow.loadURL url.format
    pathname: path.join __dirname, 'routes/setkey/setkey.html'
    protocol: 'file:'
    slashes: true
  mainWindow.show()
showGetKey = ->
  mainWindow.setSize 400, 200
  mainWindow.setPosition width - 400 - 10, height - 200 - 10
  mainWindow.loadURL url.format
    pathname: path.join __dirname, 'routes/getkey/getkey.html'
    protocol: 'file:'
    slashes: true
  mainWindow.show()

 
ready = ->
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
    label: 'Quit'
    click: ->
      app.quit()
  ]
  tray.setToolTip 'rSafe'
  tray.setContextMenu contextMenu
  autoUpdater.checkForUpdatesAndNotify()
  {width, height} = electron.screen.getPrimaryDisplay().workAreaSize
  #console.log width, height
  mainWindow = new BrowserWindow
    x: width - 400 - 10
    y: height - 200 - 10
    width: 400
    height: 200
    frame: false
    autoHideMenuBar: true
    show: false
  mainWindow.on 'closed', ->
    mainWindow = null
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
      getData (err) ->
        if err is 'no file'
          data = {}
        if data
          notification = new Notification
            title: 'rSafe'
            body: 'Logged in as ' + username
          notification.show()
          mainWindow.hide()
          contextMenu.getMenuItemById('login').visible = false
          contextMenu.getMenuItemById('logout').visible = true
          contextMenu.getMenuItemById('setkey').visible = true
          contextMenu.getMenuItemById('getkey').visible = true
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
          keynote = new Notification
            title: 'rSafe'
            body: 'capturing'
          keynote.show()
      else
        noAsterix = 0
    else
      if keychar is '\b'
        captured = captured.substr 0, captured.length - 1
        if captured.length is 0
          capturing = false
      else if event.keychar is 27
        captured = ''
        capturing = ''
        setting = false
        currentKey = ''
      else if keychar is '='
        currentKey = captured
        captured = ''
        capturing = false
        setting = true
      else if setting and keychar is '"'
        inQuotes = not inQuotes
      else if keychar is ' ' and not inQuotes
        if setting
          if password
            dataUpdated = true
            data = data or {}
            if captured is 'clip'
              captured = clipboard.readText()
            dotty.put data, "#{currentKey}._value", captured
            saveData (err) ->
              if not err
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
        keynote.body = captured
keyUp = (event) ->
  if event.rawcode is 160
    shiftDown = false