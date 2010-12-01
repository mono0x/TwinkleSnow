
var MaxVisibleTweets = 100;

function Tab(param) {
  this.id = param.id;
  this.name = param.name;
  this.tweets = [];
  this.oldTweets = [];
  this.cursor = null;
  this.readIndex = -1;
  this.scrollTop = 0;
  this.unreadCount = 0;
  this.onread = null;
}
Tab.prototype.receiveTweet = function(tweet) {
  this.incrementUnreadCount();

  this.tweets.push(tweet);

  var view = jQuery('#views > #view-' + this.id);

  var data = tweet.data;

  var element = jQuery('<div />')
    .attr({ id: 'tweet-' + data.id, 'data-tweet-id': data.id })
    .append(tweet.html);
  view.prepend(element);

  var tabs = View.tabs;
  var insertTarget = element;
  var inReplyToStatusId = data.in_reply_to_status_id;
  var j = 0;
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
    if(j == 1) {
      insertTarget.after(
        jQuery('<div />').addClass('expand-reply').attr('data-tweet-id', tweet.data.id).append(
          jQuery('<a />').text('...').attr('href', '').click(function() {
            jQuery(this).parent().slideUp('fast', function() { jQuery(this).remove(); });
            jQuery('#views > div > div.reply[data-tweet-id="' + tweet.data.id + '"]').slideDown('fast');
            return false;
          })));
    }
    element = jQuery('<div />')
      .append(reply.html)
      .attr({
        id : 'reply-' + tweet.data.id + '-' + reply.data.id,
        'data-tweet-id' : tweet.data.id,
        'data-reply-id' : reply.data.id
      })
      .addClass('reply');
    insertTarget.after(element);
    insertTarget = element;
    inReplyToStatusId = reply.data.in_reply_to_status_id;
    ++j;
  }

  this.removeOldTweets();
  
  var visible = view.is(':visible');
  if(!visible) {
    view.show();
  }
  var height = 0;
  jQuery('div[data-tweet-id="' + data.id + '"]').each(function() {
    height += jQuery(this).outerHeight(true);
  });
  this.scrollTop += height;
  if(!visible) {
    view.hide();
  }
  else {
    jQuery.scrollTo(this.scrollTop, 0);
    this.scrollTop = jQuery(window).scrollTop();
  }
};
Tab.prototype.removeTweet = function() {
  var tweet = this.tweets.shift();
  this.oldTweets.push(tweet, 0);

  jQuery('div[data-tweet-id="' + tweet.data.id + '"]').remove();
};

Tab.prototype.setCursorById = function(id) {
  if(this.cursor === null) {
    return;
  }
  var tweets = this.tweets;
  for(var i = 0, n = tweets.length; i < n; ++i) {
    if(tweets[i].data.id == id) {
      this.setCursor(i);
      break;
    }
  }
};
Tab.prototype.setCursor = function(pos) {
  var tweets = this.tweets;
  if(pos < 0) {
    pos = 0;
  }
  else if(pos >= tweets.length) {
    pos = tweets.length - 1;
  }
  if(pos > this.readIndex) {
    this.unreadCount -= pos - this.readIndex;
    this.readIndex = pos;
    if(typeof this.onread == 'function') {
      this.onread(this.tweets[this.readIndex].data.id_str);
    }
  }
  this.cursor = pos;
  this.updateCursor();
  this.updateCounter();
};
Tab.prototype.upCursor = function() {
  if(this.cursor !== null) {
    this.setCursor(this.cursor + 1);
  }
};
Tab.prototype.downCursor = function() {
  if(this.cursor !== null) {
    this.setCursor(this.cursor - 1);
  }
};
Tab.prototype.adjustCursor = function() {
  if(this.cursor === null) {
    return;
  }

  var scrollTop = jQuery(window).scrollTop();
  var tweets = this.tweets;

  this.scrollTop = scrollTop;

  var height = jQuery(window).height();

  var skipped = true;

  var i = this.cursor;
  while(i > 0) {
    var tweet = tweets[i];
    var element = jQuery('#tweet-' + tweet.data.id);
    var top = element.offset().top;
    if(top - scrollTop >= 0) {
      break;
    }
    skipped = false;
    --i;
  }
  if(skipped) {
    i = this.cursor;
    while(i < tweets.length - 1) {
      var tweet = tweets[i];
      var element = jQuery('#tweet-' + tweet.data.id);
      var top = element.offset().top;
      if(top + element.outerHeight(true) - scrollTop <= height) {
        break;
      }
      skipped = false;
      ++i;
    }
    this.updateCounter();
  }
  if(!skipped) {
    this.setCursor(i);
    this.updateCursor();
  }
};
Tab.prototype.updateCursor = function() {
  var view = jQuery('#views > #view-' + this.id);
  view.find('.selected').removeClass('selected');
  if(this.cursor !== null) {
    var tweet = this.tweets[this.cursor];
    var element = view.find('#tweet-' + tweet.data.id).addClass('selected');
    var top = element.offset().top;
    if(top - jQuery(window).scrollTop() < 0 || top + element.outerHeight(true) - jQuery(window).scrollTop() >= jQuery(window).height()) {
      jQuery.scrollTo(element);
      this.scrollTop = jQuery(window).scrollTop();
    }
  }
};

Tab.prototype.incrementUnreadCount = function() {
  ++this.unreadCount;
  this.updateCounter();
}

Tab.prototype.updateCounter = function() {
  jQuery('#tab-' + this.id)
    .toggleClass('has-unread', this.unreadCount > 0)
    .find('.unread > .count')
      .text(this.unreadCount);
};

Tab.prototype.removeOldTweets = function() {
  var tweets = this.tweets;
  while(tweets.length - this.unreadCount > 100) {
    --this.readIndex;
    if(--this.cursor < 0) {
      this.cursor = 0;
    }
    var tweet = tweets.shift();
    jQuery('div[data-tweet-id="' + tweet.data.id_str + '"]').remove();
  }
};

