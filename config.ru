require 'sinatra'
require 'json'
require 'ir_b'

class ExampleApp < Sinatra::Base
  configure :production, :development do
    enable :logging
  end

  get "/test" do
    if params["MODE"] == "init"
      init_response
    else
      buffering_proxy_test
    end
  end
  get "/bind" do
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

  private

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
end

map '/channel' do
  run ExampleApp.new
end
