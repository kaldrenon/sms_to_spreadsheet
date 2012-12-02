#RHoK 
require 'sinatra'
require 'rubygems'
require 'tropo-webapi-ruby'

use Rack::Session::Pool

post '/index.json' do
  @v = Tropo::Generator.parse request.env["rack.input"].read
  @t = Tropo::Generator.new

  a = @v[:session][:initial_text].split(/ *, */)
  puts @v[:session][:timestamp]
  puts @v[:session][:initial_text]
  puts Time.now
  
  
  
  a.insert(0, Time.now)
  
  File.open("out.csv", "a") {|f| f.write(a.join(',') + "\n")}

  #@t.say("We got your purchase!")
  return @t.response
end

def performAction(a)
	a[0] = a[0].upcase
	
	case a[0]
		when "BOUGHT" then buy(a)
		when "BUY" then buy(a)
		when "SOLD" then sell(a)
		when "SELL" then sell(a)
		when "RECENT" then recent(a)
		when "PAST" then recent(a)
		when "BALANCE" then balance(a)
		when "HELP" then help(a)
		else unknownCommand(a)
end

def buy(command)
	File.open("out.csv", "a") {|f| f.write("bought" + command[1..-1].join(',') + "\n")}
end

def sell(command)
	File.open("out.csv", "a") {|f| f.write("sold" + command[1..-1].join(',') + "\n")}
end

def recent(command)
	lines = File.open("out.csv", "r").readlines
	lines = lines[-command[1].to_i..-1
	
	@t.say(lines.join)
end

def balance(command)

end

def unknownCommand(command)
	@t.say("Sorry couldn't understand your message, please use following syntax: [command] [arguments]\nText HELP for available commands")
end

def help(command)
	@t.say("The available commands are: BUY, SELL, RECENT, BALANCE)
end

