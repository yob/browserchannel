require 'sinatra'
require 'json'
require 'securerandom'
require 'thread_safe'
require 'ir_b'

class Session

  attr_reader :id

  def initialize
    @id = SecureRandom.hex
  end

end

class ExampleApp < Sinatra::Base
  configure :production, :development do
    enable :logging
  end

  configure do
    set :sessions, ThreadSafe::Hash.new
  end

  get "/test" do
    if params["MODE"] == "init"
      init_response
    else
      buffering_proxy_test
    end
  end
  get "/bind" do
    sid = params["SID"]
    aid = params["AID"]
    if sid
      session = settings.sessions[sid]
    else
      session = Session.new
      settings.sessions[session.id] ||= session
      # TODO send the new session details
    end

    if session.nil?
      notfound_response
    elsif params['TYPE'] == 'terminate'
      #@session.terminate
      terminate_session_response
    elsif request.request_method == "GET"
      # long lived backchannel sending data from the server to the client
      handle_backchannel
    elsif request.request_method == "POST"
      # short lived forward-channel sending data from the client to the server
      # @session.receive_upload(request.something)
    end
  end

  private

  def notfound_response
    [
      404,
      {'Content-Type' => 'application/javascript'},
      ""
    ]
  end

  def init_response
    host_prefix = nil
    blocked_prefix = nil
    [
      200,
      {'Content-Type' => 'application/javascript'},
      JSON.dump([host_prefix, blocked_prefix])
    ]
  end

  def buffering_proxy_test
    env['rack.hijack'].call
    env['rack.hijack_io'] << "HTTP/1.1 200 OK\n"
    env['rack.hijack_io'] << "Content-Type: plain/text\n"
    env['rack.hijack_io'] << "Transfer-Encoding: chunked\n"
    env['rack.hijack_io'] << "\n"
    env['rack.hijack_io'] << 5.to_s(16) << "\r\n"
    env['rack.hijack_io'] << "11111\r\n"
    sleep 2
    env['rack.hijack_io'] << 1.to_s(16) << "\r\n"
    env['rack.hijack_io'] << "2\r\n"

    env['rack.hijack_io'].close
  end

  def terminate_session_response
    [
      200,
      {'Content-Type' => 'application/javascript'},
      ""
    ]
  end

  def handle_backchannel
    env['rack.hijack'].call
    env['rack.hijack_io'] << "HTTP/1.1 200 OK\n"
    env['rack.hijack_io'] << "Content-Type: plain/text\n\n"
    3.times do |i|
      env['rack.hijack_io'] << "#{i}\n"
      env['rack.hijack_io'].flush
      sleep 1
    end
    env['rack.hijack_io'].close
  end
end

map '/channel' do
  run ExampleApp.new
end
