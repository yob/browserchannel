require 'thread_safe'
require 'sinatra/base'
require 'json'

module BrowserChannel
  class App < Sinatra::Base
    disable :protection
    set :sessions, false

    configure :production, :development do
      enable :logging
    end

    configure do
      set :bcSessions, ThreadSafe::Hash.new
    end

    get "/test" do
      if params["MODE"] == "init"
        init_response
      else
        buffering_proxy_test
      end
    end
    get "/bind" do
      aid = params["AID"]
      session = get_or_create_session(params["SID"])
      if session.nil?
        notfound_response
      elsif params['TYPE'] == 'terminate'
        settings.bcSessions.delete(session.id)
        session.terminate
        terminate_session_response
      else
        # long lived backchannel sending data from the server to the client
        handle_backchannel(session)
      end
    end

    # short lived forward-channel sending data from the client to the server
    post "/bind" do
      bcSession = get_or_create_session(params["SID"])
      msg_count = params["count"].to_i
      response = nil
      msg_count.times do |i|
        payload = params["req#{i}_JSON"] || "{}"
        response = bcSession.receive_data(JSON.parse(payload))
      end
      headers = {
        'Content-Type' => 'text/plain',
        'Cache-Control' => 'no-cache, no-store, max-age=0, must-revalidate',
        'X-Content-Type-Options' => 'nosniff',
        'Access-Control-Allow-Origin' => "*",
        'Access-Control-Max-Age' => '3600',
        #'Date' => ''
      }
      if bcSession.sent_count == 0
        # this is a new session and we need to send a special response
        response = JSON.dump([[0,["c",bcSession.id,nil,8]]])
        response = "#{response.size}\n#{response}"
        headers["Content-Length"] = response.bytesize
        [200, headers, response]
      else
        # this is an existing session and we need to send a book-keeping response
        [200, headers, JSON.dump(response)]
      end
    end

    def send_chunk(data)
      puts "#send_chunk #{data.inspect}"
      env['rack.hijack_io'] << data.bytesize.to_s(16) << "\r\n"
      env['rack.hijack_io'] << "#{data}\r\n"
      env['rack.hijack_io'] << "\r\n"
      env['rack.hijack_io'].flush
    end

    def close
      env['rack.hijack_io'].close
    end

    private

    def get_or_create_session(sid)
      if sid
        session = settings.bcSessions[sid]
      else
        session = Session.new
        settings.bcSessions[session.id] ||= session
        # TODO send the new session details
      end
      session
    end

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
      headers = {
        'Content-Type' => 'text/plain',
        'Cache-Control' => 'no-cache, no-store, max-age=0, must-revalidate',
        'X-Content-Type-Options' => 'nosniff',
        'X-Accept' => "application/json; application/x-www-form-urlencoded",
        'Access-Control-Allow-Origin' => "*",
        'Access-Control-Max-Age' => '3600',
        #'Date' => ''
      }
      [
        200,
        headers,
        JSON.dump([host_prefix, blocked_prefix])
      ]
    end

    def buffering_proxy_test
      env['rack.hijack'].call
      env['rack.hijack_io'] << "HTTP/1.1 200 OK\n"
      env['rack.hijack_io'] << "Access-Control-Allow-Origin: *\n"
      env['rack.hijack_io'] << "Access-Control-Max-Age: 3600\n"
      env['rack.hijack_io'] << "Content-Type: text/plain\n"
      env['rack.hijack_io'] << "Cache-Control: no-cache, no-store, max-age=0, must-revalidate\n"
      env['rack.hijack_io'] << "X-Content-Type-Options: nosniff\n"
      env['rack.hijack_io'] << "Date: #{header_formatted_time}\n"
      env['rack.hijack_io'] << "Transfer-Encoding: chunked\n"
      env['rack.hijack_io'] << "\n"
      env['rack.hijack_io'] << 5.to_s(16) << "\r\n"
      env['rack.hijack_io'] << "11111\r\n"
      env['rack.hijack_io'] << "\r\n"
      sleep 2
      env['rack.hijack_io'] << 1.to_s(16) << "\r\n"
      env['rack.hijack_io'] << "2\r\n"
      env['rack.hijack_io'] << "\r\n"

      env['rack.hijack_io'].close
    rescue Errno::EPIPE
      # the client closed the connection and we're OK with that
    end

    def terminate_session_response
      [
        200,
        {'Content-Type' => 'application/javascript'},
        ""
      ]
    end

    def header_formatted_time
      Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S %Z")
    end

    def handle_backchannel(bcSession)
      env['rack.hijack'].call
      env['rack.hijack_io'] << "HTTP/1.1 200 OK\n"
      env['rack.hijack_io'] << "Access-Control-Allow-Origin: *\n"
      env['rack.hijack_io'] << "Access-Control-Max-Age: 3600\n"
      env['rack.hijack_io'] << "Content-Type: plain/text\n"
      env['rack.hijack_io'] << "Cache-Control: no-cache, no-store, max-age=0, must-revalidate\n"
      env['rack.hijack_io'] << "X-Content-Type-Options: nosniff\n"
      env['rack.hijack_io'] << "Date: #{header_formatted_time}\n"
      env['rack.hijack_io'] << "Connection: keep-alive\n"
      env['rack.hijack_io'] << "Transfer-Encoding: chunked\n\n"
      bcSession.add_backchannel(self)
      #env['rack.hijack_io'])
      #env['rack.hijack_io'].close
    end

  end
end

