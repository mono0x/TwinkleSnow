
Array.prototype.find = function(cond) {
  for(var i = 0, n = this.length; i < n; ++i) {
    if(cond(this[i])) {
      return this[i];
    }
  }
  return null;
};

$(function() {
  if(!("WebSocket" in window)) {
    alert('WebSocket is not supported in this browser.');
    return;
  }

  $('#main').hide();
  var currentTab = null;
  tabs.forEach(function(tab) {
    tab.tweets = [];
    tab.read = 0;
    tab.unreadCount = 0;
    tab.scrollTop = 0;
    $('#views').append(
      $('<div />').attr({ id : 'view-' + tab.id }));
    $('#tabs').append(
      $('<li />').attr({ id : 'tab-' + tab.id }).append(
        $('<a />').attr({ href : '#tabs/' + tab.name }).append(
          tab.name, ' ', $('<span />').addClass('unread').append(
            '(', $('<span />').addClass('count').append('0'), ')'))));
  });

  var updateUnreadCount = function(tab, count) {
    tab.unreadCount = count;
    var tabElement = $('#tab-' + tab.id);
    tabElement.find('.unread > .count').text(count);
    tabElement.toggleClass('has-unread', count > 0);
  };
  
  var findTweetAndElementOnTop = function() {
    var scrollTop = $(window).scrollTop();
    var tweets = currentTab.tweets;
    var n = tweets.length;
    for(var i = n - 1; i >= 0; --i) {
      var tweet = tweets[i];
      var id = tweet.data.id;
      var tweetElement = $('#tweet-' + id);
      if(tweetElement.offset().top - scrollTop >= 0) {
        return {
          tweet : tweet,
          element : tweetElement,
          count : n - i - 1
        };
      }
    }
    return null;
  }
  
  var updateRead = function() {
    var te = findTweetAndElementOnTop();
    if(te == null) {
      return;
    }
    var tweet = te.tweet;
    var id = tweet.data.id;
    var count = te.count;
    if(id > currentTab.read) {
      currentTab.read = id;
      var path = '/api/read/' + currentTab.id + '/' + id;
      $.getJSON(path, {}, function(data) {});
      updateUnreadCount(currentTab, count);
    }
  }

  var updateHash = function() {
    if(window.location.hash.match(/^#tabs\/([a-z0-9\-]+)$/)) {
      var name = RegExp.$1;
      if(currentTab != null) {
        $('#tab-' + currentTab.id).removeClass('active');
        updateRead();
        var read = currentTab.read;
        $.each($('#view-' + currentTab.id + ' div[id^="tweet-"]:not(.read)').get().reverse(), function(i, e) {
          var element = $(e);
          if(element.attr('id').match(/^tweet-(\d+)$/)) {
            var id = parseInt(RegExp.$1);
            if(id <= read) {
              element.addClass('read');
              $('div[id^="reply-' + id + '"]').addClass('read');
            }
            else {
              return false;
            }
          }
        });
      }
      currentTab = tabs.find(function(t) { return t.name == name; });
      var viewId = '#view-' + currentTab.id;
      $('#views > div:not(' + viewId + ')').hide();
      $('#views > div:hidden' + viewId).show();
      $('#tab-' + currentTab.id).addClass('active');
      $.scrollTo(currentTab.scrollTop);
    }
  };

  $(window).bind('hashchange', function() {
    updateHash();
  });
  if(!window.location.hash) {
    window.location.hash = '#tabs/timeline';
  }
  updateHash();

  $(window).scroll(function() {
    currentTab.scrollTop = $(window).scrollTop();
  });

  var prependTweet = function(tweet) {
    var data = tweet.data;
    var user = data.user;
    var screen_name = user.screen_name;
    var id = data.id;

    var view = $('#views > #view-' + tweet.tab_id);
    var element = $('<div />')
      .attr({ 'id' : 'tweet-' + tweet.data.id })
      .append(tweet.html);
    view.prepend(element);

    var inserted = false;
    var insertTarget = element;
    var inReplyToStatusId = data.in_reply_to_status_id;
    while(inReplyToStatusId) {
      var reply = null;
      for(var i = 0, n = tabs.length; i < n; ++i) {
        reply = tabs[i].tweets.find(function(tweet) {
          return inReplyToStatusId == tweet.data.id;
        });
        if(reply != null) {
          break;
        }
      }
      if(reply == null) {
        break;
      }
      var element = $('<div />')
          .append(reply.html)
          .attr({ 'id' : 'reply-' + tweet.data.id + '-' + reply.data.id})
          .addClass('reply');
      insertTarget.after(element);
      insertTarget = element;
      inReplyToStatusId = reply.data.in_reply_to_status_id;
      inserted = true;
    }

    var visible = view.is(':visible');
    if(!visible) {
      view.show();
    }
    var height = $('#tweet-' + data.id).outerHeight(true);
    $('div[id^="reply-' + data.id + '"]').each(function() {
      height += $(this).outerHeight(true);
    });
    if(!visible) {
      view.hide();
    }
    var tab = tabs[tweet.tab_id];
    tab.scrollTop += height;
    if(currentTab.id == tab.id) {
      $.scrollTo(currentTab.scrollTop, 0);
    }
  };

  var connectWebSocket = function(passwordHash) {
    var setMessage = function(text) {
      $('#auth > p').text(text);
    };

    setMessage('connecting...');

    var authorizeError = false;
    var ws = new WebSocket('ws://' + webSocket.host + ':' + webSocket.port);
    ws.onmessage = function(e) {
      ws.onmessage = function(e) {
        if(e.data == 'success') {
          ws.onmessage = function(e) {
            var tweets = eval('(' + e.data + ')');
            tweets.forEach(function(tweet) {
              var tab = tabs[tweet.tab_id];
              tab.tweets.push(tweet);
              updateUnreadCount(tab, tab.unreadCount + 1);
              prependTweet(tweet);
            });
          };
          ws.onclose = function() {
            connectWebSocket(passwordHash);
          };
          $('#auth').fadeOut(300);
          $('#main').fadeIn(300);
          setInterval(updateRead, 3000);
        }
        else if(e.data == 'failure') {
          setMessage('failure');
          ws.close();
        }
      };
      var serverRandom = e.data;
      var clientRandom = CybozuLabs.SHA1.calc(Math.random().toString());
      ws.send(CybozuLabs.SHA1.calc(passwordHash + serverRandom + clientRandom) + ',' + clientRandom);
    };
    ws.onclose = function() {
    };
    ws.onopen = function() {
    };
  };

  $('#auth form').submit(function() {
    var passwordHash = CybozuLabs.SHA1.calc($('#auth input[type="password"]').val());
    connectWebSocket(passwordHash);
    return false;
  });

  var getTweetIdFromAnchor = function(anchor) {
    var id = $(anchor).parent().parent().parent().attr('id');
    if(id.match(/^tweet-(\d+)$/)) {
      return parseInt(RegExp.$1);
    }
    return null;
  };

  var getTweetFromAnchor = function(anchor) {
    var id = getTweetIdFromAnchor(anchor);
    if(id == null) {
      return null;
    }
    var tweets = currentTab.tweets;
    for(var i = 0, n = tweets.length; i < n; ++i) {
      if(tweets[i].data.id == id) {
        return tweets[i];
      }
    }
    return null;
  };

  $('a[href="#retweet"]').live('click', function() {
    var tweet = getTweetFromAnchor(this);
    $.getJSON('/api/retweet/' + tweet.data.id, {}, function(data) {
    });
    return false;
  });
  $('a[href="#unfollow"]').live('click', function() {
    var tweet = getTweetFromAnchor(this);
    $.getJSON('/api/unfollow/' + tweet.data.user.id, {}, function(data) {
    });
    return false;
  });
  $('a[href="#fav"]').live('click', function() {
    var tweet = getTweetFromAnchor(this);
    $.getJSON('/api/create_favorite/' + tweet.data.id, {}, function(data) {
    });
    return false;
  });

  $('input').keypress(function(e) {
    e.stopPropagation();
  });

  var nextTweet = function() {
    var te = findTweetAndElementOnTop();
    if(te) {
      var next = te.element.nextAll('div[id^="tweet-"]').eq(0);
      if(next.length > 0) {
        $.scrollTo(next, 0);
      }
    }
  };

  var prevTweet = function() {
    var te = findTweetAndElementOnTop();
    if(te) {
      var prev = te.element.prevAll('div[id^="tweet-"]').eq(0);
      if(prev.length > 0) {
        $.scrollTo(prev, 0);
      }
    }
  };

  var prevTab = function() {
    if(currentTab != null) {
      var n = tabs.length;
      var id = currentTab.id;
      for(var i = 0; i < n - 1; ++i) {
        id = (id + n - 1) % n;
        var tab = tabs[id];
        if(tab.unreadCount > 0) {
          window.location.hash = '#tabs/' + tab.name;
          return;
        }
      }
    }
  };

  var nextTab = function() {
    if(currentTab != null) {
      var n = tabs.length;
      var id = currentTab.id;
      for(var i = 0; i < n - 1; ++i) {
        id = (id + 1) % n;
        var tab = tabs[id];
        if(tab.unreadCount > 0) {
          window.location.hash = '#tabs/' + tab.name;
          return;
        }
      }
    }
  };

  $(document).keypress(function(e) {
    switch(e.keyCode) {
    case 106: // j
      nextTweet();
      e.preventDefault();
      break;

    case 107: // k
      prevTweet();
      e.preventDefault();
      break;

    case 97: // a
      prevTab();
      e.preventDefault();
      break;

    case 115: // s
      nextTab();
      e.preventDefault();
      break;

    }
  });

});
