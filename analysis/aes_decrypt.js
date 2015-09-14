
var AES = require('crypto-js/aes');
var zerorpc = require("zerorpc");

function hex2a(hex) {
  var str = '';
  for (var i = 0; i < hex.length; i += 2)
      str += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
  return str;
}

//console.log(hex2a(AES.decrypt(process.argv[2], process.argv[3]).toString()))


var server = new zerorpc.Server({
    decrypt: function(enc, key, reply) {
        var dec = hex2a(AES.decrypt(enc, key).toString());
        reply(null, dec);
    }
});

server.bind("tcp://0.0.0.0:4242");

