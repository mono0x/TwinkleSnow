# -*- coding: utf-8 -*-

require 'ramaze'
require 'json'
require 'twitter'
require 'digest/sha1'

require './model'
require './configloader'

class ControllerBase < Ramaze::Controller
  @@config = ConfigLoader.load_file('data/config.rb')
end

class MainController < ControllerBase
  map '/'
  engine :Erubis

  def index
    unless session[:screen_name] == @@config.basic_auth[:account]
      unless session[:screen_name]
        redirect '/oauth/request_token'
      else
        redirect '/error/auth'
      end
    end
    @tabs = @@config.tabs
    @web_socket = @@config.web_socket
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
      session[:screen_name] = credentials[:screen_name]
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

  def unfollow(user_id)
    unless session[:screen_name] == @@config.basic_auth[:account]
      return { :result => 'failure' }.to_json
    end
    begin
      oauth = Twitter::OAuth.new(
        @@config.oauth[:consumer_token], @@config.oauth[:consumer_secret])
      oauth.authorize_from_access(
        session[:access_token],
        session[:access_token_secret])
      twitter = Twitter::Base.new(oauth)
      twitter.friendship_destroy(user_id)

      { :result => 'success' }.to_json
    rescue Twitter::Unauthorized => e
      { :result => 'failure' }.to_json
    end
  end

  def read(tab_id, tweet_id)
    unless session[:screen_name] == @@config.basic_auth[:account]
      return { :result => 'failure' }.to_json
    end
    tt = @@config.tokyo_tyrant
    db = tokyo_tyrant(tt[:host], tt[:port])
    q = TokyoTyrant::RDBQRY.new(db)
    q.addcond 'tab_id', TokyoTyrant::RDBQRY::QCNUMEQ, tab_id.to_i.to_s
    q.addcond '', TokyoTyrant::RDBQRY::QCNUMLE, tweet_id.to_i.to_s
    res = q.search.each do |key|
      db.delete key
    end
    { :result => 'success', :tab_id => tab_id.to_i, :read => tweet_id.to_i }.to_json
  end

end

