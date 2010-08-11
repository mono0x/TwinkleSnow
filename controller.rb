# -*- coding: utf-8 -*-

require 'ramaze'
require 'json'
require 'twitter'
require 'digest/sha1'

require './model'
require './configloader'

class ControllerBase < Ramaze::Controller
  @@config = ConfigLoader.load_file('data/config.rb')

  private

  def create_twitter
    begin
      oauth = Twitter::OAuth.new(
        @@config.oauth[:consumer_token],
        @@config.oauth[:consumer_secret])
      oauth.authorize_from_access(
        session[:access_token],
        session[:access_token_secret])
      Twitter::Base.new(oauth)
    rescue Twitter::Unauthorized => e
      nil
    end
  end
end

class MainController < ControllerBase
  map '/'
  engine :Erubis

  def index
    unless session[:screen_name] == @@config.basic_auth[:account]
      redirect '/oauth/request_token'
    end
    @tabs = @@config.tabs
    @web_socket = @@config.web_socket
    twitter = create_twitter
    @user = twitter.verify_credentials
  end

end

class ErrorController < ControllerBase
  map '/error'

  def auth
    response.status = 401
    'Authentication Required'
  end

end

class OAuthController < ControllerBase
  map '/oauth'

  def request_token
    oauth = Twitter::OAuth.new(
      @@config.oauth[:consumer_token], @@config.oauth[:consumer_secret])
    oauth.consumer_options[:authorize_path] = '/oauth/authenticate'
    request_token = oauth.request_token(
      :oauth_callback => "#{base_uri}/oauth/access_token")
    session[:request_token] = request_token.token
    session[:request_token_secret] = request_token.secret
    redirect request_token.authorize_url
  end

  def access_token
    begin
      oauth = Twitter::OAuth.new(
        @@config.oauth[:consumer_token], @@config.oauth[:consumer_secret])
      oauth.authorize_from_request(
        session[:request_token],
        session[:request_token_secret],
        request[:oauth_verifier])
      access_token = oauth.access_token
      twitter = Twitter::Base.new(oauth)
      credentials = twitter.verify_credentials
      session[:access_token] = access_token.token
      session[:access_token_secret] = access_token.secret
      session[:screen_name] = credentials.screen_name
      redirect '/'
    rescue Twitter::Unauthorized => e
    end
  end

  private 

  def base_uri
    default_port = (request.scheme == 'http') ? 80 : 443
    port = (request.port != default_port) ? ":#{request.port}" : ''
    "#{request.scheme}://#{request.host}#{port}"
  end

end

class APIController < ControllerBase
  map '/api'

  def retweet(tweet_id)
    unless session[:screen_name] == @@config.basic_auth[:account]
      return failure
    end
    twitter = create_twitter
    return failure unless twitter
    twitter.retweet tweet_id
    success
  end

  def unfollow(user_id)
    unless session[:screen_name] == @@config.basic_auth[:account]
      return failure
    end
    twitter = create_twitter
    return failure unless twitter
    twitter.friendship_destroy user_id
    success
  end

  def create_favorite(tweet_id)
    unless session[:screen_name] == @@config.basic_auth[:account]
      return failure
    end
    twitter = create_twitter
    return failure unless twitter
    twitter.favorite_create tweet_id
    success
  end

  def read(tab_id, tweet_id)
    unless session[:screen_name] == @@config.basic_auth[:account]
      return failure
    end
    tt = @@config.tokyo_tyrant
    db = tokyo_tyrant(tt[:host], tt[:port])
    q = TokyoTyrant::RDBQRY.new(db)
    q.addcond 'tab_id', TokyoTyrant::RDBQRY::QCNUMEQ, tab_id.to_i.to_s
    q.addcond '', TokyoTyrant::RDBQRY::QCNUMLE, tweet_id.to_i.to_s
    res = q.search.each do |key|
      db.delete key
    end
    success :tab_id => tab_id.to_i, :read => tweet_id.to_i
  end

  private

  def make_result(result, h)
    hash = h.dup
    hash.store :result, result
    hash.to_json
  end

  def success(hash = {})
    make_result 'success', hash
  end

  def failure(hash = {})
    make_result 'failure', hash
  end

end

