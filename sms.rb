#RHoK 
require 'sinatra'
require 'rubygems'
require 'tropo-webapi-ruby'

use Rack::Session::Pool

post '/index.json' do

  # Receive a text message from an external device
  @v = Tropo::Generator.parse request.env["rack.input"].read
  @t = Tropo::Generator.new

  # Check the incoming number against a whitelist
  json = File.open("whitelist.json","r").read
  @whitelist = JSON.parse(json)
  @sender_num = @v[:session][:from][:id]
  @message_text = @v[:session][:initial_text]

  # Check for sender number in whitelist
  if(@whitelist.keys.include? @sender_num or @message_text.start_with?("rhok"))
    puts "got a valid sender"
    if(@message_text.start_with?("rhok"))
      @whitelist[@sender_num] = {"name"=>"RHoK Tester","location"=>"Innovation Center"}
      @message_text.slice! /rhok */
    end

    performAction(@message_text)
  else
    puts "invalid number!"
    @t.say("The number you contacted belongs to a Peace Corps project. Your number is not recognized.")
  end

  puts @message_text

  # Write the line to a CSV
  File.open("test.csv", "a") {|f| f.write(@message_text + "\n")}

  return @t.response
end

def performAction(a)
  a = a.split(/ *, */)
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
end

def buy(command)
  File.open("out.csv", "a") {|f| f.write("bought" + command[1..-1].join(',') + "\n")}
end

def sell(command)
  File.open("out.csv", "a") {|f| f.write("sold" + command[1..-1].join(',') + "\n")}
end

def recent(command)
  lines = File.open("out.csv", "r").readlines
  lines = lines[-command[1].to_i..-1]

  @t.say(lines.join)
end

def balance(command)

end

def unknownCommand(command)
  @t.say("Sorry, I couldn't understand your message. Please use following syntax: [command] [arguments]\nText HELP for available commands")
end

def help(command)
  puts "running help function"
  @t.say("The available commands are: BUY, SELL, RECENT, BALANCE")
end

