# -*- coding: utf-8 -*-

require 'uri'
require 'logger'
require 'json'
require 'digest/sha1'
require 'time'
require 'twitter'
require 'erubis'

require_relative 'workaround'

require_relative 'configloader'
require_relative 'loginpage'
require_relative 'tweetstorage'
require_relative 'tweetrenderer'
require_relative 'websocket'
require_relative 'userstream'
require_relative 'twitterapi'
require_relative 'imkayac'

log = Logger.new(STDOUT)
log.level = Logger::INFO

config = ConfigLoader.load_file('data/config.rb')

LoginPage.new(config.oauth, config.web_socket).create

twitter = TwitterAPI.new(config.oauth)

tweet_renderer = TweetRenderer.new

tweet_storage = TweetStorage.new

kayac = ImKayac.new(config.im_kayac[:user_name], config.im_kayac[:secret_key]) if config.im_kayac

EventMachine.run do
  log.info 'server start'
  web_socket = WebSocket.new(config.web_socket[:port], config.password, log)
  web_socket.on_connect do |ws|
    ws.send({ 'tabs' => config.tabs }.to_json)
    ws.send({ 'tweets' => tweet_storage.unread }.to_json)
  end
  web_socket.on_receive do |m, ws|
    json = JSON.parse(m)
    case json['action']
    when 'read'
      tweet_storage.delete json['tab_id'], json['tweet_id']
    when 'retweet'
      twitter.retweet json['id']
    when 'favorite'
      twitter.create_favorite json['id']
    end
  end
  web_socket.start

  log.info 'stream start'
  stream = UserStream.new(config.oauth)
  stream.each_item do |item|
    data = JSON.parse(item)
    log.info data
    next unless data['text']
    id = data['id']
    text = data['text']
    screen_name = data['user']['screen_name']

    next if config.block[:words].any? {|w| text =~ w }

    if kayac && text =~ /@#{config.account}/
      kayac.send "#{screen_name}: #{text}", config.im_kayac[:handler]
    end

    tabs = config.tabs
    tab = tabs.find {|t| t[:users].any? {|u| u == screen_name } } || tabs[0]
    tab_id = tab[:id]

    html = tweet_renderer.render(data)
    web_socket.broadcast({
      'tweets' => [
        {
          'tab_id' => tab_id,
          'data' => data,
          'html' => html,
        }
      ] }.to_json)
    tweet_storage.append tab_id, data, html
  end
  stream.on_error do |m|
    log.error m
    EventMachine.stop_event_loop
  end
  stream.on_max_reconnects do |timeout, retries|
    log.error "max reconnects #{timeout} : #{retries}"
    EventMachine.stop_event_loop
  end
  stream.start

end

