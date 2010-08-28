(function($) {

Array.prototype.find = function(cond) {
  for(var i = 0, n = this.length; i < n; ++i) {
    if(cond(this[i])) {
      return this[i];
    }
  }
  return null;
};

var openUri = function(uri) {
  var a = document.createElement("a");
  a.href = uri;
  a.target = "_blank";
  var e = document.createEvent("MouseEvents");
  e.initMouseEvent("click", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 1, null);
  a.dispatchEvent(e);
};

$(function() {
  if(!("WebSocket" in window)) {
    alert('WebSocket is not supported in this browser.');
    return;
  }

  var tabs = null;

  $('#main').hide();
  var currentTab = null;

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
  };

  var updateSelected = function(tab) {
    if(!tab) {
      tab = currentTab;
    }
    var view = $('#views > #view-' + tab.id);
    view.find('.selected').removeClass('selected');
    if(tab.selectedIndex !== null) {
      var tweet = tab.tweets[tab.selectedIndex];
      view.find('#tweet-' + tweet.data.id).addClass('selected');
    }
  };

  var updateRead = function() {
    var te = findTweetAndElementOnTop();
    if(!te) {
      return;
    }
    var tweet = te.tweet;
    var id = tweet.data.id;
    var count = te.count;
    if(id > currentTab.read) {
      currentTab.read = id;
      updateUnreadCount(currentTab, count);
      if(ws) {
        ws.send(JSON.stringify({
          action : 'read',
          tab_id : currentTab.id,
          tweet_id : currentTab.read
        }));
      }
    }
  };

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
            var id = parseInt(RegExp.$1, 10);
            if(id <= read) {
              element.addClass('read');
              $('div[id^="reply-' + id + '"]').addClass('read');
            }
            else {
              return false;
            }
          }
          return true;
        });
      }
      currentTab = tabs.find(function(t) { return t.name == name; });
      var viewId = '#view-' + currentTab.id;
      $('#views > div:not(' + viewId + ')').hide();
      $('#views > div:hidden' + viewId).show();
      $('#tab-' + currentTab.id).addClass('active');
      $.scrollTo(currentTab.scrollTop);
      updateRead();
    }
  };

  $(window).bind('hashchange', function() {
    updateHash();
  });

  $(window).scroll(function() {
    currentTab.scrollTop = $(window).scrollTop();
    if(currentTab.selectedIndex !== null) {
      var skiped = true;
      var scrollTop = $(window).scrollTop();
      var tweet;
      var te;
      while(currentTab.selectedIndex > 0) {
        tweet = currentTab.tweets[currentTab.selectedIndex];
        te = $('#tweet-' + tweet.data.id);
        if(te.offset().top - scrollTop >= 0) {
          break;
        }
        --currentTab.selectedIndex;
        skiped = false;
      }
      if(skiped) {
        var windowHeight = $(window).height();
        while(currentTab.selectedIndex < currentTab.tweets.length - 1) {
          tweet = currentTab.tweets[currentTab.selectedIndex];
          te = $('#tweet-' + tweet.data.id);
          if(te.offset().top + te.outerHeight(true) - scrollTop <= windowHeight) {
            break;
          }
          ++currentTab.selectedIndex;
          skiped = false;
        }
      }
      if(!skiped) {
        updateSelected();
      }
    }
    updateRead();
  });

  var prependTweet = function(tweet) {
    var data = tweet.data;

    var view = $('#views > #view-' + tweet.tab_id);

    var element = $('<div />')
      .attr({ id : 'tweet-' + tweet.data.id })
      .append(tweet.html);
    view.prepend(element);

    if(!tabs[tweet.tab_id].selectedIndex) {
      tabs[tweet.tab_id].selectedIndex = 0;
      updateSelected(tabs[tweet.tab_id]);
    }

    var insertTarget = element;
    var inReplyToStatusId = data.in_reply_to_status_id;
    while(inReplyToStatusId) {
      var reply = null;
      for(var i = 0, n = tabs.length; i < n; ++i) {
        reply = tabs[i].tweets.find(function(t) {
          return inReplyToStatusId == t.data.id;
        });
        if(reply) {
          break;
        }
      }
      if(!reply) {
        break;
      }
      element = $('<div />')
        .append(reply.html)
        .attr({ id : 'reply-' + tweet.data.id + '-' + reply.data.id})
        .addClass('reply');
      insertTarget.after(element);
      insertTarget = element;
      inReplyToStatusId = reply.data.in_reply_to_status_id;
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

  var connectionState = 0;
  var ws = null;
  var connectWebSocket = function(passwordHash) {
    var setMessage = function(text) {
      $('#auth > p').text(text);
    };

    setMessage('connecting...');

    ws = new WebSocket('ws://' + webSocket.host + ':' + webSocket.port);
    ws.onmessage = function(e) {
      var json = JSON.parse(e.data);
      switch(connectionState) {
        case 0:
          {
            var serverRandom = json.server_random;
            var clientRandom = CybozuLabs.SHA1.calc(Math.random().toString());
            var hash = CybozuLabs.SHA1.calc(passwordHash + serverRandom + clientRandom);
            ws.send(JSON.stringify({
              hash : hash,
              client_random : clientRandom
            }));
            ++connectionState;
          }
          break;
        case 1:
          {
            if(json.result == 'success') {
              ++connectionState;
            }
            else {
              setMessage('failure');
              ws.close();
            }
          }
          break;
        case 2:
          {
            tabs = json.tabs;
            tabs.forEach(function(tab) {
              tab.tweets = [];
              tab.read = 0;
              tab.unreadCount = 0;
              tab.scrollTop = 0;
              tab.selectedIndex = null;
              $('#views').append(
                $('<div />').attr({ id : 'view-' + tab.id }));
              $('#tabs').append(
                $('<li />').attr({ id : 'tab-' + tab.id }).append(
                  $('<a />').attr({ href : '#tabs/' + tab.name }).append(
                    tab.name, ' ', $('<span />').addClass('unread').append(
                      '(', $('<span />').addClass('count').append('0'), ')'))));
            });
            if(!window.location.hash) {
              window.location.hash = '#tabs/timeline';
            }
            updateHash();
            ++connectionState;
            $('#auth input[type="password"]').blur();
            $('#auth').fadeOut(300);
            $('#main').fadeIn(300);
          }
          break;
        case 3:
          {
            json.tweets.forEach(function(tweet) {
              var tab = tabs[tweet.tab_id];
              tab.tweets.push(tweet);
              updateUnreadCount(tab, tab.unreadCount + 1);
              prependTweet(tweet);
            });
            updateRead();
          }
          break;
        default:
          break;
      }
    };
    ws.onclose = function() {
      ws = null;
      switch(connectionState) {
        case 0:
          break;
        case 1:
          break;
        case 2:
        case 3:
          {
            connectionState = 0;
            connectWebSocket(passwordHash);
          }
          break;
        default:
          break;
      }
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
      return parseInt(RegExp.$1, 10);
    }
    return null;
  };

  var getTweetFromAnchor = function(anchor) {
    var id = getTweetIdFromAnchor(anchor);
    if(!id) {
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

  var retweet = function(tweet) {
    ws.send(JSON.stringify({
      action : 'retweet',
      id : tweet.data.id
    }));
  };

  var unfollow = function(user) {
    ws.send(JSON.stringify({
      action : 'unfollow',
      user_id : user.id
    }));
  };

  var createFavorite = function(tweet) {
    ws.send(JSON.stringify({
      action : 'favorite',
      id : tweet.data.id
    }));
  };

  $('a[href="#retweet"]').live('click', function() {
    var tweet = getTweetFromAnchor(this);
    retweet(tweet);
    return false;
  });
  $('a[href="#unfollow"]').live('click', function() {
    var tweet = getTweetFromAnchor(this);
    retweet(tweet.data.user);
    return false;
  });
  $('a[href="#fav"]').live('click', function() {
    var tweet = getTweetFromAnchor(this);
    createFavorite(tweet);
    return false;
  });

  $('input').keypress(function(e) {
    e.stopPropagation();
  });

  var nextTweet = function() {
    if(currentTab.selectedIndex === null) {
      return;
    }
    if(currentTab.selectedIndex == 0) {
      return;
    }
    --currentTab.selectedIndex;
    var tweet = currentTab.tweets[currentTab.selectedIndex];
    var te = $('#tweet-' + tweet.data.id);
    if(te.offset().top + te.outerHeight(true) - $(window).scrollTop() >= $(window).height()) {
      $.scrollTo(te.offset().top + te.outerHeight(true) - $(window).height());
    }
    updateSelected();
  };

  var prevTweet = function() {
    if(currentTab.selectedIndex === null) {
      return;
    }
    if(currentTab.selectedIndex == currentTab.tweets.length - 1) {
      return;
    }
    ++currentTab.selectedIndex;
    var tweet = currentTab.tweets[currentTab.selectedIndex];
    var te = $('#tweet-' + tweet.data.id);
    if(te.offset().top - $(window).scrollTop() < 0) {
      $.scrollTo(te);
    }
    updateSelected();
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

  var openExternalLink = function(openAll) {
    if(currentTab === null) {
      return;
    }
    if(currentTab.selectedIndex === null) {
      return;
    }
    var tweet = currentTab.tweets[currentTab.selectedIndex];
    var element = $('#tweet-' + tweet.data.id);
    console.log(element.find('a.external'));
    var externalLinks = element.find('a.external');
    if(openAll) {
      externalLinks.each(function() {
        openUri($(this).attr('href'));
      });
    }
    else if(externalLinks.size() > 0) {
      openUri(externalLinks.eq(0).attr('href'));
    }
  };

  $('#views > div > div').live('click', function(e) {
    var selectedIndex = currentTab.selectedIndex;
    if(selectedIndex === null) {
      return;
    }
    var id = $(this).attr('id');
    if(id.match(/^tweet-(\d+)$/) || id.match(/^reply-(\d+)-(?:\d+)$/)) {
      var clickedId = parseInt(RegExp.$1, 10);
      var tweets = currentTab.tweets;
      console.log(clickedId);
      for(var i = 1, n = tweets.length; i < n; ++i) {
        var f = selectedIndex + i;
        var b = selectedIndex - i;
        if(b < 0 && f >= n) {
          break;
        }
        if(b >= 0 && tweets[b].data.id == clickedId) {
          selectedIndex = b;
          break;
        }
        if(f < n && tweets[f].data.id == clickedId) {
          selectedIndex = f;
          break;
        }
      }
      console.log(selectedIndex);
      currentTab.selectedIndex = selectedIndex;
      updateSelected();
    }
  });

  $(document).mousewheel(function(e, delta) {
    if(delta > 0) {
      for(var i = 0; i < delta; ++i) {
        prevTweet();
      }
      e.preventDefault();
    }
    else if(delta < 0) {
      for(var i = delta; i < 0; ++i) {
        nextTweet();
      }
      e.preventDefault();
    }
  });

  $(document).keypress(function(e) {
    switch(e.keyCode) {
    case 'j'.charCodeAt(0):
      nextTweet();
      e.preventDefault();
      break;

    case 'k'.charCodeAt(0):
      prevTweet();
      e.preventDefault();
      break;

    case 'a'.charCodeAt(0):
      prevTab();
      e.preventDefault();
      break;

    case 's'.charCodeAt(0):
      nextTab();
      e.preventDefault();
      break;

    case 'r'.charCodeAt(0):
      if(currentTab.selectedIndex !== null) {
        retweet(currentTab.tweets[currentTab.selectedIndex]);
      }
      e.preventDefault();
      break;

    case 'U'.charCodeAt(0):
      if(currentTab.selectedIndex !== null) {
        unfollow(currentTab.tweets[currentTab.selectedIndex].data.user);
      }
      e.preventDefault();
      break;

    case 'f'.charCodeAt(0):
      if(currentTab.selectedIndex !== null) {
        createFavorite(currentTab.tweets[currentTab.selectedIndex]);
      }
      e.preventDefault();
      break;

    case 'v'.charCodeAt(0):
      openExternalLink();
      e.preventDefault();
      break;
      
    case 'V'.charCodeAt(0):
      openExternalLink(true);
      e.preventDefault();
      break;

    default:
      break;
    }
  });

});

})(jQuery);
