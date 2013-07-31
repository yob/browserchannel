require 'sinatra'
require 'ir_b'

class ExampleApp < Sinatra::Base
  configure :production, :development do
    enable :logging
  end

  get "/" do
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

map '/' do
  run ExampleApp.new
end
