
var View = {};

View.tabs = [];
View.currentTab = null;

View.appendTab = function(tab) {
  this.tabs.push(tab);

  var view =
    jQuery('<div />')
      .attr({ id: 'view-' + tab.id, 'data-tab-id': tab.id })
      .hide();
  jQuery('#views').append(view);

  var counter =
    jQuery('<span />')
      .addClass('unread')
      .append('(', jQuery('<span />').addClass('count').append('0'), ')');
  var tabText =
    jQuery('<a />')
      .attr({ href: '#tabs/' + tab.name })
      .append(tab.name, ' ', counter);
  jQuery('#tabs').append(
    jQuery('<li />')
      .attr({ id: 'tab-' + tab.id, 'data-tab-id': tab.id })
      .append(tabText));

  if(this.currentTab === null) {
    this.switchTab(tab);
  }
};

View.receiveTweet = function(tweet) {
  this.tabs[tweet.tab_id].receiveTweet(tweet);
};

View.switchTab = function(tab) {
  if(tab === null) {
    return;
  }

  if(this.currentTab !== null) {
    jQuery('#tabs > #tab-' + this.currentTab.id).removeClass('active');
    jQuery('#views > #view-' + this.currentTab.id).hide();
  }
  this.currentTab = tab;

  jQuery('#tabs > #tab-' + this.currentTab.id).addClass('active');
  jQuery('#views > #view-' + this.currentTab.id).show();
  jQuery.scrollTo(this.currentTab.scrollTop, 0);
  this.currentTab.scrollTop = jQuery(window).scrollTop();

  if(tab.cursor === null && tab.tweets.length > 0) {
    tab.setCursor(0);
  }
  

  /*
      if(currentTab != null) {
        addReadTweets();
        updateRead();
        jQuery('#tabs > li[data-tab-id="' + currentTab.id + '"]').removeClass('active');
        jQuery('#views > div[data-tab-id="' + currentTab.id + '"]').hide();
        readTweets.forEach(function(tweet) {
          jQuery('#views > div[data-tab-id="' + currentTab.id + '"] > div[data-tweet-id="' + tweet.data.id + '"]')
            .addClass('read').attr({ 'data-read' : '1' });
        });
        readTweets = [];
      }
      currentTab = tabs.find(function(t) { return t.name == name; });
      jQuery('#views > div[data-tab-id="' + currentTab.id + '"]').show();
      jQuery('#tabs > li[data-tab-id="' + currentTab.id + '"]').addClass('active');
      jQuery.scrollTo(currentTab.scrollTop);
      updateRead();
    }
    */
};

View.findTabByName = function(name) {
  return this.tabs.find(function(tab) { return tab.name == name; });
};


