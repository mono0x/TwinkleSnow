# -*- coding: utf-8 -*-

require 'uri'
require 'logger'
require 'eventmachine'
require 'em-websocket'
require 'twitter/json_stream'
require 'json'
require 'digest/sha1'
require 'time'

require './configloader'
require './model'

log = Logger.new(STDOUT)
log.level = Logger::INFO

config = ConfigLoader.load_file('data/config.rb')

uri = URI.parse("http://chirpstream.twitter.com/2b/user.json")

channel = EM::Channel.new

tt = config.tokyo_tyrant
db = tokyo_tyrant(tt[:host], tt[:port])

REPLY_RE = /(@([A-Za-z0-9_]+))/
HASHTAG_RE = /(#([A-Za-z0-9_]+))/
URI_RE = /(#{URI.regexp([ 'http', 'https' ])})/
BREAK_RE = /(\r\n)/

TEXT_RE = /#{REPLY_RE}|#{HASHTAG_RE}|#{URI_RE}|#{BREAK_RE}/

def to_html(data)
  body = data['text'].gsub(TEXT_RE) do
    case
    when $1 then "<a target=\"_blank\" href=\"http://twitter.com/#$2\">#$1</a>"
    when $3 then "<a target=\"_blank\" href=\"http://search.twitter.com/search?q=%23#$4\">#$3</a>"
    when $5 then "<a target=\"_blank\" href=\"#$5\">#$5</a>"
    when $6 then '<br />'
    end
  end
  id = data['id']
  user = data['user']
  screen_name = user['screen_name']
  created_at = Time.parse(data['created_at'])

  <<-"EOS"
    <div id="tweet-#{id}">
      <div class="content">
        <div class="text">
          <span class="screen_name">#{screen_name}</span> #{body}
        </div>
        <div class="information">
          <a target="_blank" href="http://twitter.com/#{screen_name}/status/#{id}">#{created_at.strftime('%m/%d %H:%M')}</a>
          via
          #{data['source']}
          |
            <a target="_blank" href="http://twitter.com/?status=@#{screen_name}&in_reply_to_status_id=#{id}&in_reply_to=#{screen_name}">Reply</a>
            <a href="#retweet">Retweet</a>
            <a target="_blank" href="http://twitter.com/?status= RT @#{screen_name}: #{data['text']}">RT</a>
            <a href="#unfollow">Unfollow</a>
            <a href="#fav">Fav</a>
          </div>
        </div>
        <div class="icon">
          <img width="48" height="48" src="#{user['profile_image_url']}" />
        </div>
    </div>
  EOS
end

def authorize(hash, client_random, server_random, password)
  password_hash = Digest::SHA1.hexdigest(password)
  Digest::SHA1.hexdigest(password_hash + server_random + client_random) == hash
end

EventMachine.run do
  EventMachine.defer do
    log.info 'server start'

    EM::WebSocket.start(:host => '0.0.0.0', :port => 13001) do |ws|
      ws.onopen do
        sid = nil
        server_random = Digest::SHA1.hexdigest(rand.to_s)

        ws.send server_random

        ws.onmessage do |m|
          log.info "<#{sid}>: #{m}"
          # auth
          if m =~ /\A([0-9a-f]+),([0-9a-f]+)\z/ && authorize($1, $2, server_random, config.password)
            sid = channel.subscribe do |m|
              ws.send m
            end
            log.info "#{sid} connected"
            ws.send 'success'
            # push unread tweets
            q = TokyoTyrant::RDBQRY.new(db)
            q.setorder '', TokyoTyrant::RDBQRY::QONUMASC
            q.search.each do |key|
              value = db.get(key)
              channel.push({
                :tab_id => value['tab_id'],
                :data => JSON.parse(value['data']),
                :html => value['html'],
              }.to_json)
            end
          else
            ws.send 'failure'
          end
        end

        ws.onclose do
          if sid
            log.info "#{sid} closed"
            channel.unsubscribe sid
          end
        end

      end
    end
  end

  basic_auth = config.basic_auth
  stream = Twitter::JSONStream.connect(
    :host => uri.host,
    :path => uri.path,
    :auth => "#{basic_auth[:account]}:#{basic_auth[:password]}"
  )
  log.info 'stream start'

  stream.each_item do |item|
    data = JSON.parse(item)
    log.info data.inspect
    if data['text']
      id = data['id']
      text = data['text']
      screen_name = data['user']['screen_name']

      block = config.block
      next if block[:words].any? {|w| text =~ w}
      next if block[:screen_names].any? {|n| screen_name == n}

      matched_tab = config.tabs.find {|tab| tab[:users].any? {|u| u == screen_name}}
      tab_id = matched_tab ? matched_tab[:id] : 0

      html = to_html(data)
      channel.push({ :tab_id => tab_id, :data => data, :html => html, }.to_json)
      db.put id, { 'tab_id' => tab_id, 'data' => item, :html => html, }
    end
  end

  stream.on_error do |m|
    log.info m
  end

  stream.on_max_reconnects do |timeout, retries|
    log.info "max reconnects #{timeout} : #{retries}"
  end

end

