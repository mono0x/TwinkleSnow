
var ConnectionState = {
  Ready: 0,
  Connecting: 1,
  Connected: 2,
  Receiving: 3
};

function TweetReceiver(ws) {
  this.webSocket = ws;
  this.state = ConnectionState.Ready;
  this.connection = null;
  this.onconnect = null;
  this.onreceive = null;
  this.password = null;
}
TweetReceiver.prototype.onmessage = function(event) {
  var json = JSON.parse(event.data);
  switch(this.state) {
    case ConnectionState.Ready: {
      var passwordHash = CybozuLabs.SHA1.calc(this.password);
      var serverRandom = json.server_random;
      var clientRandom =
        CybozuLabs.SHA1.calc(Math.random().toString());
      var hash =
        CybozuLabs.SHA1.calc(passwordHash + serverRandom + clientRandom);
      this.connection.send(JSON.stringify({
        hash: hash, client_random: clientRandom
      }));
      this.state = ConnectionState.Connecting;
      break;
    }
    case ConnectionState.Connecting: {
      if(json.result == 'success') {
        this.state = ConnectionState.Connected;
      }
      else {
        this.connection.close();
        this.state = ConnectionState.Ready;
      }
      break;
    }
    case ConnectionState.Connected: {
      if(typeof this.onconnect == 'function') {
        this.onconnect(json.tabs);
      }
      this.state = ConnectionState.Receiving;
      break;
    }
    case ConnectionState.Receiving: {
      if(typeof this.onreceive == 'function') {
        this.onreceive(json.tweets);
      }
      break;
    }
  }
};
TweetReceiver.prototype.onclose = function() {
  this.connection = null;
  if(this.state == ConnectionState.Receiving) {
    this.state = ConnectionState.Ready;
    this.connect();
  }
  else {
    this.state = ConnectionState.Ready;
  }
};
TweetReceiver.prototype.connect = function(password) {
  this.password = password;
  this.connection =
    new WebSocket('ws://' + this.webSocket.host + ':' + this.webSocket.port);
  var receiver = this;
  this.connection.onmessage = function(event) {
    receiver.onmessage(event);
  };
  this.connection.onclose = function() {
    receiver.onclose();
  };
};
TweetReceiver.prototype.send = function(obj) {
  this.connection.send(JSON.stringify(obj));
};

