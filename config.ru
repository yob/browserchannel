require 'browser_channel'

map '/channel' do
  run BrowserChannel::App.new
end
