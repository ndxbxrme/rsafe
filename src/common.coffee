'use strict'
_ = require('lodash')
module.exports =
  list: (key, data, defer) ->
    if data
      keybits = key.split('.')
      object = data
      f = 0
      while f < keybits.length
        enckey = keybits[f]
        if object[enckey]
          object = object[enckey]
        else
          if enckey
            defer.reject null
        f++
      list = []
      for prop of object
        if prop.indexOf('_') != 0
          list.push prop
      defer.resolve list
    else
      defer.reject null
    return
  remove: (key, data) ->
    if !data
      data = {}
    keybits = key.split('.')
    object = data
    enckey = undefined
    f = 0
    while f < keybits.length - 1
      enckey = keybits[f]
      if object[enckey]
      else
        object[enckey] = {}
      object = object[enckey]
      f++
    enckey = keybits[keybits.length - 1]
    delete object[enckey]
    data
  set: (key, value, data) ->
    if !data
      data = {}
    keybits = key.split('.')
    object = data
    f = 0
    while f < keybits.length
      enckey = keybits[f]
      if object[enckey]
      else
        object[enckey] = {}
      object = object[enckey]
      f++
    object._value = value
    data
  setObject: (key, value, data) ->
    if !data
      data = {}
    keybits = key.split('.')
    object = data
    f = 0
    while f < keybits.length
      enckey = keybits[f]
      if object[enckey]
      else
        object[enckey] = {}
      object = object[enckey]
      f++
    _.merge object, value
    data
  get: (key, data, defer) ->
    if data
      keybits = key.split('.')
      object = data
      f = 0
      while f < keybits.length
        enckey = keybits[f]
        if object[enckey]
          object = object[enckey]
        else
          defer.reject null
        f++
      defer.resolve object._value
    else
      defer.reject null
    defer.promise
  getObject: (key, data, defer) ->
    if data
      keybits = key.split('.')
      object = data
      f = 0
      while f < keybits.length
        enckey = keybits[f]
        if object[enckey]
          object = object[enckey]
        else
          defer.reject null
        f++
      defer.resolve object
    else
      defer.reject null
    defer.promise
