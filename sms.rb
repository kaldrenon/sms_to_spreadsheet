#RHoK 
require 'sinatra'
require 'rubygems'
require 'tropo-webapi-ruby'

use Rack::Session::Pool

post '/index.json' do

  v = Tropo::Generator.parse request.env["rack.input"].read
  t = Tropo::Generator.new

  a = v[:session][:initial_text].split(/ *, */)
  puts v[:session][:timestamp]
  puts v[:session][:initial_text]
  puts Time.now
  
  a.insert(0, Time.now)
  
  File.open("out.csv", "a") {|f| f.write(a.join(',') + "\n")}

  #t.say("We got your purchase!")
  return t.response
end

