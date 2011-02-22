# -*- coding: utf-8 -*-

require 'twitter'
require 'erubis'

class LoginPage

  def initialize(token, web_socket)
    Twitter.configure do |config|
      config.consumer_key = token[:consumer_token]
      config.consumer_secret = token[:consumer_secret]
      config.oauth_token = token[:access_token]
      config.oauth_token_secret = token[:access_secret]
    end
    @twitter = Twitter::Client.new
    @eruby = Erubis::Eruby.new(open('view/index.rhtml').read)
    @web_socket = web_socket
  end

  def create
    user = @twitter.verify_credentials
    open('static/index.html', 'w') do |f|
      f << @eruby.result({ :user => user, :web_socket => @web_socket.to_json })
    end
  end

end

