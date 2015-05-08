#!/usr/bin/env node
//'use strict';

var argv = require('minimist')(process.argv.slice(2)),
    chalk = require('chalk'),
    rsafe = require('./rsafe.service'),
    readline = require('readline');

if(argv._.indexOf('setup') === 0 || argv.setup) {
  setup();
}
else if(argv._.indexOf('login') === 0) {
  rsafe.login(argv);
}
else if(argv._.indexOf('logout') === 0) {
  rsafe.logout(argv);
}
else if(argv._.indexOf('set') === 0) {
  rsafe.set(argv);
}
else if(argv._.indexOf('remove') === 0) {
  rsafe.remove(argv);
}
else if(argv._.indexOf('get') === 0) {
  rsafe.get(argv);
}
else if(argv._.indexOf('rename') === 0) {
  rsafe.rename(argv);
}
else if(argv._.indexOf('list') === 0) {
  rsafe.list(argv, function(err, result){
    
    console.log(result); 
  });
}
else if(argv._.indexOf('add') === 0) {
  rsafe.add(argv);
}
else if(argv._.indexOf('password') === 0) {
  rsafe.password(argv);
}
else if(argv._.indexOf('username') === 0) {
  rsafe.username(argv);
}
else if(argv._.indexOf('help') === 0) {
  rsafe.help(argv);
}
else if(argv._.length === 0) {
  //interactive mode
  var methods = 'get set list remove rename login logout setup add username password help'.split(' ');
  console.log(chalk.yellow.bold('interactive mode - type ') + chalk.green.bold('help') + chalk.yellow.bold(' for a list of commands, ') + chalk.green.bold('exit') + chalk.yellow.bold(' or ') + chalk.green.bold('quit') + chalk.yellow.bold(' to exit'));
  console.log(chalk.yellow.bold('Use tab for autocomplete'));
  console.log('');
  var completer = function(line, callback) {
    var hits = methods.filter(function(c) { return c.indexOf(line) === 0;});
    var foundMethod;
    methods.forEach(function(method) {
      var r = RegExp('^' + method + ' ');
      if(line.search(r)===0) {
        foundMethod = true;
        line = line.replace(r, '');
        var root = line.substring(0, line.lastIndexOf('.'));
        var search = line.substring(line.lastIndexOf('.') + 1);
        rsafe.list({_:[null, root || '_all']}, function(err, results) {
          var subhits = results.filter(function(c) { return c.indexOf(search) === 0;});
          callback(null, [subhits.length ? subhits : results, search]);
        });
      }
    });
    if(!foundMethod) {
      callback(null, [hits.length ? hits : methods, line]);
    }
  };
  var rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    completer: completer
  });
  var prompt = function() {
    rl.question('> ', function(answer) {
      if(['quit', 'exit', 'q', 'x'].indexOf(answer)!==-1) {
        rl.close(); 
      }
      else {
        var foundMethod;
        methods.forEach(function(method) {
          var r = RegExp('^' + method + '[ ]*');
          if(answer.search(r)===0) {
            foundMethod = true;
            var line = answer.replace(r, '');
            var key = line.substring(0, line.indexOf(' '));
            var val = line.substring(line.indexOf(' ') + 1); 
            rsafe[method]({_:[null, key || val, val]}, function(err, result){
              if(result) {
                console.log(result); 
              }
              rl._refreshLine();
              prompt();
            });
          }
        });
        if(!foundMethod) {
          prompt(); 
        }
      }
    });
  };
  prompt();
}