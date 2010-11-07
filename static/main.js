(function(jQuery) {

if(!("WebSocket" in window)) {
  alert('WebSocket is not supported in this browser.');
  return;
}

jQuery(function() {

var Actions = {};
Actions.upCursor = function() {
  suspendScrollEvent(function() {
    View.currentTab.upCursor();
  });
};
Actions.downCursor = function() {
  suspendScrollEvent(function() {
    View.currentTab.downCursor();
  });
};
Actions.upTab = function() {
  suspendScrollEvent(function() {
    var tabCount = View.tabs.length;
    if(tabCount > 0) {
      var i = (View.currentTab.id + tabCount - 1) % tabCount;
      location.hash = '#tabs/' + View.tabs[i].name;
    }
  });
};
Actions.downTab = function() {
  suspendScrollEvent(function() {
    var tabCount = View.tabs.length;
    if(tabCount > 0) {
      var i = (View.currentTab.id + 1) % tabCount;
      location.hash = '#tabs/' + View.tabs[i].name;
    }
  });
};
Actions.retweet = function() {
  var tab = View.currentTab;
  if(tab.cursor === null) {
    return;
  }
  var tweet = tab.tweets[tab.cursor];
  receiver.send({
    action: 'retweet',
    id: tweet.data.id
  });
};
Actions.createFavorite = function() {
  var tab = View.currentTab;
  if(tab.cursor === null) {
    return;
  }
  var tweet = tab.tweets[tab.cursor];
  receiver.send({
    action: 'favorite',
    id: tweet.data.id
  });
};

var receiver = new TweetReceiver(webSocket);
receiver.onconnect = function(tabs) {
  tabs.forEach(function(param) {
    var tab = new Tab(param)
    tab.onread = function(id) {
      receiver.send({
        action : 'read',
        tab_id : tab.id,
        tweet_id : id
      });
    }
    View.appendTab(tab);
  });
  jQuery('#auth input[type="password"]').blur();
  jQuery('#auth').fadeOut(300);
  jQuery('#main').fadeIn(300);
};
receiver.onreceive = function(tweets) {
  tweets.forEach(function(tweet) {
    View.receiveTweet(tweet);
  });
  var tab = View.currentTab;
  if(tab.cursor === null && tab.tweets.length > 0) {
    tab.setCursor(0);
  }
};

jQuery(window).bind('hashchange', function() {
  if(location.hash.match(/^#tabs\/([a-z0-9\-]+)$/)) {
    var nextTab = View.findTabByName(RegExp.$1);
    View.switchTab(nextTab);
  }
  else {
    location.hash = '#tabs/timeline';
    View.switchTab(View.findTabByName('timeline'));
  }
});
jQuery(window).trigger('hashchange');

jQuery('#auth form').submit(function() {
  var password = jQuery('#auth input[type="password"]').val();
  receiver.connect(password);
  return false;
});

jQuery('#views > div > div').live('click', function(e) {
  var id = parseInt(jQuery(this).attr('data-tweet-id'), 10);
  View.currentTab.setCursorById(id);
});

jQuery('input').bind('keydown', function(e) {
  e.stopPropagation();
});

var scrollHandler = function() {
  View.currentTab.adjustCursor();
};
jQuery(window).bind('scroll', scrollHandler);

var suspendScrollEvent = function(f) {
  jQuery(window).unbind('scroll', scrollHandler);
  f();
  jQuery(window).bind('scroll', scrollHandler);
};

jQuery(window)
  .bind('keydown', 'j', function(e) {
    Actions.downCursor();
  })
  .bind('keydown', 'k', function(e) {
    Actions.upCursor();
  })
  .bind('keydown', 'a', function(e) {
    Actions.upTab();
  })
  .bind('keydown', 's', function(e) {
    Actions.downTab();
  })
  .bind('keydown', 't', function(e) {
    Actions.retweet();
  })
  .bind('keydown', 'f', function(e) {
    Actions.createFavorite();
  });

jQuery(window).mousewheel(function(e, delta) {
  var max = jQuery(document).height() - jQuery(window).height();
  if(delta > 0 && View.currentTab.scrollTop == 0) {
    View.currentTab.upCursor();
    return false;
  }
  else if(delta < 0 && View.currentTab.scrollTop == max) {
    View.currentTab.downCursor();
    return false;
  }
  return true;
});

jQuery('a[href="#retweet"]').live('click', function() {
  var id = parseInt(jQuery(this).parent().parent().parent().attr('data-tweet-id'), 10);
  View.currentTab.setCursorById(id);
  Actions.retweet();
  return false;
});
jQuery('a[href="#fav"]').live('click', function() {
  var id = parseInt(jQuery(this).parent().parent().parent().attr('data-tweet-id'), 10);
  View.currentTab.setCursorById(id);
  Actions.createFavorite();
  return false;
});

jQuery('#main').hide();

});

})(jQuery);
