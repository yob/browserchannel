require 'thread_safe'
require 'thread'
require 'securerandom'
require 'json'

module BrowserChannel
  class Session

    attr_reader :id, :message_count, :sent_count

    def initialize
      @id = SecureRandom.hex(4)
      @backchannel = nil
      @mutex = Mutex.new
      @messages = ThreadSafe::Array.new
      @message_count = 0
      @sent_count = 0
      self.push(auth: "1d5915528c74a1cf9069ce0e8754aa93")
    end

    # queues an array of data to be sent back to the client
    #
    def push(array)
      log "#push #{array.inspect}"
      @mutex.synchronize do
        @message_count += 1
        @messages << [@message_count, array]
        if @backchannel
          flush_messages
        end
      end
    end

    # data POSTed by the client arrives here
    def receive_data(data)
      log "#receive_data #{data.inspect}"
      # {"doc"=>"test-document", "open"=>true, "snapshot"=>nil, "type"=>"text", "create"=>true}
      if data["doc"] == "test-document" && data["create"]
        self.push(doc: "test-document", create: true, meta: true, open: true, v: 0)
      end
      @mutex.synchronize do
        session_bound = @backchannel ? 1 : 0
        pending_bytes = @messages.empty? ? 0 : JSON.dump(@messages).bytesize
        response = [session_bound, @message_count, pending_bytes]
        #@handler.call post_data
        response
      end
    end

    def add_backchannel(connection)
      @mutex.synchronize do
        @backchannel = connection
        flush_messages
      end
      Thread.new do
        3.times do
          sleep 25
          self.push ["noop"]
        end
      end
    end

    def terminate
      push(["stop"])
      @backchannel.close
    end

    private

    def log(msg)
      puts "#{@id} #{msg}"
    end

    def flush_messages
      log "#flush_messages #{@messages.inspect}"
      while @messages.any?
        payload = JSON.dump([@messages.shift])
        payload_with_len = "#{payload.bytesize}\n#{payload}"
        @backchannel.send_chunk(payload_with_len)
        @sent_count += 1
      end
    end

  end
end
