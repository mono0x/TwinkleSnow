
require 'eventmachine'
require 'em-websocket'
require 'em-http'
require 'oauth'
require 'oauth/client/em_http'

class WebSocket

  attr_reader :channel

  def initialize(port, password, log = nil)
    @port = port
    @password = password
    @log = log
    @channel = EM::Channel.new
  end

  def on_connect(&block)
    @on_connect = block
  end

  def on_receive(&block)
    @on_receive = block
  end

  def start
    EventMachine.defer do
      EM::WebSocket.start(:host => '0.0.0.0', :port => @port) do |ws|
        ws.onopen do
          sid = nil

          server_random = random
          ws.send({ 'server_random' => server_random }.to_json)

          ws.onmessage do |m|
            if sid
              @log.info "<#{sid}>: #{m}" if @log
              @on_receive.call m, ws
            else
              if sid = authorize(m, server_random, ws)
                @on_connect.call ws
              end
            end
          end

          ws.onclose do
            if sid
              @log.info "#{sid} closed" if @log
              @channel.unsubscribe sid
            end
          end

        end
      end
    end
  end

  def broadcast(json)
    @channel.push json
  end

  private

  def calculate_hash(client_random, server_random)
    Digest::SHA1.hexdigest("#@password#{server_random}#{client_random}")
  end
    
  def random
    Digest::SHA1.hexdigest(rand.to_s)   
  end

  def authorize(m, server_random, ws)
    p json = JSON.parse(m)
    p server_hash = calculate_hash(json['client_random'], server_random)
    if json['hash'] == server_hash
      sid = @channel.subscribe do |m|
        ws.send m
      end
      @log.info "#{sid} connected" if @log
      ws.send({ 'result' => 'success' }.to_json)
      return sid
    else
      ws.send({ 'result' => 'failure' }.to_json)
      return false
    end
  end

end

