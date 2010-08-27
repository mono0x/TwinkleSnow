# -*- coding: utf-8 -*-

require 'uri'
require 'logger'
require 'eventmachine'
require 'em-websocket'
require 'em-http'
require 'oauth'
require 'oauth/client/em_http'
require 'twitter/json_stream'
require 'json'
require 'digest/sha1'
require 'time'
require 'twitter'
require 'erubis'

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

require './configloader'
require './model'

def create_index_page(config)
  oauth = Twitter::OAuth.new(config.oauth[:consumer_token], config.oauth[:consumer_secret])
  oauth.authorize_from_access config.oauth[:access_token], config.oauth[:access_secret]
  twitter = Twitter::Base.new(oauth)

  user = twitter.verify_credentials

  eruby = Erubis::Eruby.new(open('view/index.rhtml').read)

  open('static/index.html', 'w') do |f|
    f << eruby.result({
      :user => user,
      :web_socket => config.web_socket.to_json,
    })
  end
end

log = Logger.new(STDOUT)
log.level = Logger::INFO

config = ConfigLoader.load_file('data/config.rb')

consumer = OAuth::Consumer.new(
  config.oauth[:consumer_token],
  config.oauth[:consumer_secret],
  :site => 'http://twitter.com')

access_token = OAuth::AccessToken.new(
  consumer,
  config.oauth[:access_token],
  config.oauth[:access_secret])

create_index_page config

channel = EM::Channel.new

tt = config.tokyo_tyrant
db = tokyo_tyrant(tt[:host], tt[:port])

REPLY_RE = /@([A-Za-z0-9_]+)/
HASHTAG_RE = /#([A-Za-z0-9_]+)/
URI_RE = /(#{URI.regexp([ 'http', 'https' ])})/
BREAK_RE = /(\n)/

TEXT_RE = /#{REPLY_RE}|#{HASHTAG_RE}|#{BREAK_RE}|#{URI_RE}/

def to_html(data)
  retweet = data['retweeted_status']
  status = retweet || data

  id = status['id']
  user = status['user']
  screen_name = user['screen_name']
  text = status['text']
  created_at = Time.parse(status['created_at'])
  in_reply_to_status_id = status['in_reply_to_status_id']
  in_reply_to_screen_name = status['in_reply_to_screen_name']

  image_preview = case text
    when %r!http://twitpic\.com/(\w+)!
      <<-"EOS"
      <a target="_blank" href="http://twitpic.com/#$1">
        <img src="http://twitpic.com/show/thumb/#$1" />
      </a>
      EOS
    when %r!http://yfrog\.com/(\w+)!
      <<-"EOS"
      <a target="_blank" href="http://yfrog.com/#$1">
        <img src="http://yfrog.com/#$1.th.jpg" />
      </a>
      EOS
    when %r!http://movapic\.com/pic/(\w+)!
      <<-"EOS"
      <a target="_blank" href="http://movapic.com/pic/#$1">
        <img src="http://image.movapic.com/pic/m_#$1.jpeg"
           width="200" height="150" />
      </a>
      EOS
    when %r!http://f\.hatena\.ne\.jp/([A-Za-z0-9])([A-Za-z0-9\-]*)/(\d{8})(\d+)!
      <<-"EOS"
      <a target="_blank" href="http://f.hatena.ne.jp/#$1#$2/#$3#$4">
        <img src="http://img.f.hatena.ne.jp/images/fotolife/#$1/#$1#$2/#$3/#$3#{$4}_120.jpg" />
      </a>
      EOS
    when %r!(http://tweetphoto\.com/\d+)!
      <<-"EOS"
      <a target="_blank" href="#$1">
        <img src="http://tweetphotoapi.com/api/TPAPI.svc/imagefromurl?size=thumbnail&url=#$1" />
      </a>
      EOS
    when %r!http://(?:www\.nicovideo\.jp/watch/|nico\.ms/)sm(\d+)!
      <<-"EOS"
      <a target="_blank" href="http://www.nicovideo.jp/watch/#$1">
        <img src="http://tn-skr2.smilevideo.jp/smile?i=#$1"
          width="200" height="150" />
      </a>
      EOS
    when %r!http://(?:www\.youtube\.com/watch\?.*v=|youtu\.be/)([A-Za-z0-9_-]+)!
      <<-"EOS"
      <a target="_blank" href="http://www.youtube.com/watch?v=#$1">
        <img src="http://i.ytimg.com/vi/#$1/3.jpg"
          width="200" height="150" />
      </a>
      EOS
  end

  content = text.gsub(TEXT_RE) do
    case
    when $1 then %!@<a target="_blank" href="http://twitter.com/#$1">#$1</a>!
    when $2 then %!<a target="_blank" href="http://search.twitter.com/search?q=%23#$2">\##$2</a>!
    when $3 then '<br />'
    when $4 then %!<a target="_blank" class="external" href="#$4">#$4</a>!
    end
  end

  source = status['source'].gsub(%r!^<a href="(.+)" rel="nofollow">(.+)</a>$!) {
    %!<a target="_blank" href="#$1">#$2</a>!
  }

  <<-"EOS"
  <div class="content">
    <div class="text">
      <a target="_blank" class="screen_name" href="http://twitter.com/#{screen_name}">#{screen_name}</a> #{content}
    </div>
    #{
      if retweet
        %!<div class="retweet">
          Retweeted by <a target="_blank" href="http://twitter.com/#{data['user']['screen_name']}">#{data['user']['screen_name']}</a>
        </div>!
      end
    }
    #{
      if image_preview
        %!<div class="image-preview">#{image_preview}</div>!
      end
    }
    <div class="information">
      #{
        if in_reply_to_status_id
          %!To <a target="_blank" href="http://twitter.com/#{in_reply_to_screen_name}/status/#{in_reply_to_status_id}">#{in_reply_to_screen_name}</a> |!
        end
      }
      <a target="_blank" href="http://twitter.com/#{screen_name}/status/#{id}">#{created_at.strftime('%m/%d %H:%M')}</a>
      via
      #{source}
      |
      <a target="_blank" href="http://twitter.com/?status=@#{screen_name}&in_reply_to_status_id=#{id}&in_reply_to=#{screen_name}">Reply</a>
      <a href="#retweet">Retweet</a>
      <a target="_blank" href="http://twitter.com/?status= RT @#{screen_name}: #{text}">RT</a>
      <a href="#unfollow">Unfollow</a>
      <a href="#fav">Fav</a>
    </div>
  </div>
  <div class="icon">
    <img width="48" height="48" src="#{user['profile_image_url']}" />
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

    EM::WebSocket.start(:host => '0.0.0.0', :port => config.web_socket[:port]) do |ws|
      ws.onopen do
        sid = nil
        server_random = Digest::SHA1.hexdigest(rand.to_s)

        ws.send server_random

        ws.onmessage do |m|
          if sid
            log.info "<#{sid}>: #{m}"
            json = JSON.parse(m)
            case json['action']
            when 'read'
              q = TokyoTyrant::RDBQRY.new(db)
              q.addcond 'tab_id', TokyoTyrant::RDBQRY::QCNUMEQ, json['tab_id'].to_s
              q.addcond '', TokyoTyrant::RDBQRY::QCNUMLE, json['tweet_id'].to_s
              q.search.each do |key|
                db.delete key
              end
            when 'retweet'
              id = json['id']
              req = EventMachine::HttpRequest.new("http://api.twitter.com/1/statuses/retweet/#{id}.json")
              http = req.post(:head => { 'Content-Type' => 'application/x-www-form-urlencoded' }) do |client|
                consumer.sign! client, access_token
              end
            when 'unfollow'
              user_id = json['user_id']
              req = EventMachine::HttpRequest.new("http://api.twitter.com/1/friendships/destroy.json")
              http = req.post(:body => { 'user_id' => user_id }, :head => { 'Content-Type' => 'application/x-www-form-urlencoded' }) do |client|
                consumer.sign! client, access_token
              end
            when 'favorite'
              id = json['id']
              req = EventMachine::HttpRequest.new("http://api.twitter.com/1/favorites/create/#{id}.json")
              http = req.post(:head => { 'Content-Type' => 'application/x-www-form-urlencoded' }) do |client|
                consumer.sign! client, access_token
              end
            end
          else
            # auth
            if m =~ /\A([0-9a-f]+),([0-9a-f]+)\z/ && authorize($1, $2, server_random, config.password)
              sid = channel.subscribe do |m|
                ws.send m
              end
              log.info "#{sid} connected"
              ws.send({ 'result' => 'success', 'tabs' => config.tabs }.to_json)
              # push unread tweets
              q = TokyoTyrant::RDBQRY.new(db)
              q.setorder '', TokyoTyrant::RDBQRY::QONUMASC
              json = q.search.map {|key|
                value = db.get(key)
                {
                  :tab_id => value['tab_id'],
                  :data => JSON.parse(value['data']),
                  :html => value['html'],
                }
              }.to_json
              ws.send json
            else
              ws.send({ 'result' => 'failure' }.to_json)
            end
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


  stream = Twitter::JSONStream.connect(
    :host => 'betastream.twitter.com',
    :path => '/2b/user.json',
    :oauth => {
      :consumer_key => config.oauth[:consumer_token],
      :consumer_secret => config.oauth[:consumer_secret],
      :access_key => config.oauth[:access_token],
      :access_secret => config.oauth[:access_secret],
    }) 

  log.info 'stream start'

  stream.each_item do |item|
    data = JSON.parse(item)
    log.info data 
    if data['text']
      id = data['id']
      text = data['text']
      screen_name = data['user']['screen_name']

      block = config.block
      next if block[:words].any? {|w| text =~ w}

      if text =~ /@#{config.account}/
        im_kayac = config.im_kayac
        if im_kayac
          message = "#{screen_name}: #{text}"
          signature = Digest::SHA1.hexdigest("#{message}#{im_kayac[:secret_key]}") 
          EventMachine::HttpRequest.new("http://im.kayac.com/api/post/#{im_kayac[:user_name]}").post(:body => {
            :message => message,
            :handler => im_kayac[:handler],
            :sig => signature,
          })
        end
      end

      matched_tab = config.tabs.find {|tab| tab[:users].any? {|u| u == screen_name}}
      tab_id = matched_tab ? matched_tab[:id] : 0

      html = to_html(data)
      channel.push([{ :tab_id => tab_id, :data => data, :html => html, }].to_json)
      db.put id, { 'tab_id' => tab_id, 'data' => item, :html => html, }
    end
  end

  stream.on_error do |m|
    log.error m
  end

  stream.on_max_reconnects do |timeout, retries|
    log.error "max reconnects #{timeout} : #{retries}"
  end

end

