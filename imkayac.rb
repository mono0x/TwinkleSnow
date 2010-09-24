
require 'eventmachine'
require 'em-http'
require 'digest/sha1'

class ImKayac

  API_URI = 'http://im.kayac.com/api/post/'

  def initialize(user_name, secret_key)
    @user_name = user_name
    @secret_key = secret_key
  end

  def send(message, handler)
    EventMachine::HttpRequest.new("#{API_URI}#@user_name").post(:body => {
      :message => message,
      :handler => handler,
      :sig => calculate_signature(message),
    }, :head => { 'Content-Type' => 'application/x-www-form-urlencoded' })
  end

  private

  def calculate_signature(message)
    Digest::SHA1.hexdigest("#{message}#@secret_key")
  end

end

