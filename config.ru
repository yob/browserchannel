require 'sinatra'
require 'json'
require 'ir_b'

class ExampleApp < Sinatra::Base
  configure :production, :development do
    enable :logging
  end

  get "/test" do
    host_prefix = nil
    blocked_prefix = nil
    if params["MODE"] == "init"
      [
        200,
        {'Content-Type' => 'application/javascript'},
        JSON.dump([host_prefix, blocked_prefix])
      ]
    else
      [
        404,
        {'Content-Type' => 'application/javascript'},
        ""
      ]
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
end

map '/channel' do
  run ExampleApp.new
end
