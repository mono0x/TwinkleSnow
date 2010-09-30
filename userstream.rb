# -*- coding: utf-8 -*-

require 'eventmachine'
require 'twitter/json_stream'

class UserStream

  def initialize(oauth)
    @oauth = oauth
  end

  def each_item(&block)
    @each_item = block
  end

  def on_error(&block)
    @on_error = block
  end

  def on_max_reconnects(&block)
    @on_max_reconnects = block
  end

  def start
    stream = Twitter::JSONStream.connect(
      :host => 'userstream.twitter.com',
      :path => '/2/user.json',
      :ssl => true,
      :user_agent => 'TwinkleSnow',
      :oauth => {
        :consumer_key => @oauth[:consumer_token],
        :consumer_secret => @oauth[:consumer_secret],
        :access_key => @oauth[:access_token],
        :access_secret => @oauth[:access_secret],
      })

    stream.each_item do |item|
      @each_item.call item if @each_item
    end

    stream.on_error do |m|
      @on_error.call m if @on_error
    end

    stream.on_max_reconnects do |timeout, retries|
      @on_max_reconnects.call timeout, retries if @on_max_reconnects
    end
  end

end

