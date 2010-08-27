# -*- coding: utf-8 -*-

require 'em-http'
require 'oauth/client/em_http'
require 'twitter/json_stream'

class EventMachine::HttpClient

  def normalize_uri
      @normalized_uri ||= begin
        uri = @uri.dup
        encoded_query = encode_query(@uri, @options[:query])
        path, query = encoded_query.split("?", 2)
        uri.query = query unless encoded_query.empty?
        uri.path  = path
        uri
      end
  end

end

class Twitter::JSONStream

  def params
    {}
  end

end

