'use strict'

module.exports = (grunt) ->
  require('load-grunt-tasks') grunt
  grunt.initConfig
    watch:
      coffee:
        files: ['src/**/*.coffee', 'test/**/*.coffee', 'Gruntfile.coffee']
        tasks: ['coffeelint', 'coffee', 'file_append']
    coffee:
      options:
        sourceMap: false
        sourceRoot: ''
      server:
        files: [{
          expand: true
          cwd: 'src/'
          src: ['**/*.coffee']
          dest: 'build'
          ext: '.js'
        }, {
          expand: true
          cwd: 'test/'
          src: ['**/*test.coffee']
          dest: 'test'
          ext: '.js'
        }]
    coffeelint:
      all:
        files:
          src: [
            'src/**/*.coffee'
            'Gruntfile.coffee'
            'test/**/*.coffee'
          ]
        options:
          'no_trailing_whitespace': level: 'ignore'
          'max_line_length': level: 'ignore'
    file_append:
      default_options:
        files: [{
          prepend: '#!/usr/bin/env node\n//\'use strict\';\n'
          input: 'build/index.js'
          output: 'build/index.js'
        }]
  grunt.registerTask 'test', [
    'coffeelint'
  ]
  grunt.registerTask 'default', [
    'coffeelint'
    'coffee'
    'file_append'
    'watch'
  ]