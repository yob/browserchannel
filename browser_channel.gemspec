lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name        = "browser_channel"
  s.version     = "0.0.1"
  s.authors     = ["James Healy"]
  s.email       = ["james@yob.id.au"]
  s.summary     = "browserchannel support for rack apps"

  s.files        = Dir.glob("lib/**/*")
  s.require_path = 'lib'

  s.add_dependency "sinatra"
  s.add_dependency "thread_safe", "~> 0.0.3"
end
