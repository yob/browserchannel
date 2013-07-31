# BrowserChannel Ruby Server

This is me playing around with puma, rack hijacking and browserchannel. To try
it out:

    bundle
    bundle exec puma config.ru

    ab -n 10 -c 10 http://127.0.0.1:9292/

ab should show 10 requests finishing in 3 seconds, proving the requests are
running concurrently.
