'use strict'
stream = require 'stream'
crypto = require 'crypto'
zlib = require 'zlib'
algorithm = 'aes-256-ctr'

password = null

module.exports =
  setPassword: (_password) ->
    password = _password
  encrypt: (text, pass, cb) ->
    encrypt = crypto.createCipher algorithm, pass or password
    gzip = zlib.createGzip()
    buffer = new Buffer []
    s = new stream.Readable()
    s._read = ->
    s.push text
    s.push null
    s.pipe gzip
    .pipe encrypt
    .on 'data', (chunk) ->
      buffer = Buffer.concat [buffer, chunk]
    .on 'error', (err) ->
      cb err, null
    .on 'end', ->
      cb null, buffer
  decrypt: (buffer, pass, cb) ->
    output = []
    decrypt = crypto.createDecipher algorithm, pass or password
    unzip = zlib.createGunzip()
    b = new stream.Readable()
    b._read = ->
    b.push buffer
    b.push null
    b.pipe decrypt
    .pipe unzip
    .on 'data', (chunk) ->
      for d in chunk
        output.push String.fromCharCode d
    .on 'error', (err) ->
      cb err, null
    .on 'end', ->
      cb null, output.join ''