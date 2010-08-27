# -*- coding: utf-8 -*-

require 'twitter'
require 'erubis'

class LoginPage

  def initialize(token, web_socket)
    oauth = Twitter::OAuth.new(token[:consumer_token], token[:consumer_secret])
    oauth.authorize_from_access token[:access_token], token[:access_secret]
    @twitter = Twitter::Base.new(oauth)
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

