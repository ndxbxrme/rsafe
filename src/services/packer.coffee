'use strict'
PNG = require 'pngjs'
.PNG
stream = require 'stream'
crypto = require 'crypto'
zlib = require 'zlib'
algorithm = 'aes-256-ctr'

password = null
pad = (val, length) ->
  while val.length < length
    val = '0' + val
  val
bigInt = 
  toBytes: (val, nobits) ->
    bits = val.toString(2)
    bitPadded = pad bits, nobits
    bytes = []
    i = 0
    while i < nobits
      bytes.push eval "0b" + bitPadded.substr(i, 8)
      i += 8
    bytes
  fromBytes: (bytes) ->
    i = 0
    out = ''
    while i < bytes.length
      out += pad(bytes[i].toString(2), 8)
      i++
    eval("0b" + out)

m1 = 192
m2 = 48
m3 = 12
m4 = 3
getPointer = (pointer) ->
  Math.floor pointer * 4 / 3
writeByte = (data, byte, iPointer) ->
  writeBits data, byte, m1, 6, getPointer iPointer++
  writeBits data, byte, m2, 4, getPointer iPointer++
  writeBits data, byte, m3, 2, getPointer iPointer++
  writeBits data, byte, m4, 0, getPointer iPointer++
  iPointer
writeBits = (data, byte, mask, shift, iPointer) ->
  b = byte & mask
  b = b >> shift
  i = data[iPointer]
  i = i >> 2 << 2
  i = i | b
  data[iPointer] = i
  
module.exports =
  packer:
    writeBuffer: (ws, buffer, imgData, width, dateVal, isLast, callback) ->
      iPointer = 0
      len = buffer.length
      dateBytes = bigInt.toBytes dateVal, 64
      lenBytes = bigInt.toBytes len, 32
      dateBytes[0] = (if isLast then 1 else 0)
      for byte in dateBytes
        iPointer = writeByte imgData, byte, iPointer
      for byte in lenBytes
        iPointer = writeByte imgData, byte, iPointer
      for byte in buffer
        iPointer = writeByte imgData, byte, iPointer
      png = new PNG
        width: width
        height: width
      i = 0
      while i < imgData.length
        png.data[i] = imgData[i]
        i++
      png.pack().pipe ws
      callback()
    readBuffer: (rs, callback) ->
      iPointer = 0
      output = []
      readByte = (data) ->
        d1 = data[getPointer(iPointer++)] & m4
        d1 = d1 << 6
        d2 = data[getPointer(iPointer++)] & m4
        d2 = d2 << 4
        d3 = data[getPointer(iPointer++)] & m4
        d3 = d3 << 2
        d4 = data[getPointer(iPointer++)] & m4
        d1 | d2 | d3 | d4
      rs
      .pipe new PNG()
      .on 'parsed', ->
        i = 0
        dateBytes = []
        while i < 8
          dateBytes.push readByte @.data
          i++
        isLast = dateBytes[0] is 1
        dateBytes[0] = 0
        dateVal = bigInt.fromBytes dateBytes
        i = 0
        lenBytes = []
        while i < 4
          lenBytes.push readByte @.data
          i++
        len = bigInt.fromBytes lenBytes
        len = (len + 12) * 4
        while iPointer < len
          output.push readByte @.data
        callback null, new Buffer(output), dateVal, isLast
      .on 'end', ->
  encryptor:
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