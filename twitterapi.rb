# -*- coding: utf-8 -*-

require 'eventmachine'
require 'em-http'
require 'oauth'
require 'oauth/client/em_http'

class TwitterAPI

  attr_reader :oauth

  def initialize(oauth)
    @oauth = oauth
    @consumer = OAuth::Consumer.new(
      oauth[:consumer_token],
      oauth[:consumer_secret],
      :site => 'http://twitter.com')
    @access_token = OAuth::AccessToken.new(
      @consumer,
      oauth[:access_token],
      oauth[:access_secret])
  end

  def retweet(id)
    post_api "http://api.twitter.com/1/statuses/retweet/#{id}.json"
  end

  def unfollow(user_id)
    post_api "http://api.twitter.com/1/friendships/destroy.json", {
      :user_id => user_id,
    }
  end

  def create_favorite(id)
    post_api "http://api.twitter.com/1/favorites/create/#{id}.json"
  end

  private

  def post_api(uri, body = {})
    req = EventMachine::HttpRequest.new(uri)
    req.post(:body => body, :head => { 'Content-Type' => 'application/x-www-form-urlencoded' }) do |client|
      @consumer.sign! client, @access_token
    end
  end

end

