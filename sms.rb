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
  @sender = @v[:session][:from][:id]
  @message_text = @v[:session][:initial_text]

  # Check for sender number in whitelist
  if(@whitelist.keys.include? @sender or @message_text.start_with?("rhok"))
    puts "got a valid sender"
    if(@message_text.start_with?("rhok"))
      @whitelist[@sender] = {"name"=>"RHoK Tester","location"=>"Innovation Center"}
      @message_text.slice! /rhok */
    end

    performAction(@message_text)
  else
    puts "invalid number!"
    #@t.say("The number you contacted belongs to a Peace Corps project. Your number is not recognized.")
  end

  puts @message_text

  # Write the line to a CSV
  File.open("test.csv", "a") {|f| f.write(@message_text + "\n")}

  return @t.response
end

def performAction(command)
  command = command.split(/ *, */)
  # Force upper case for the command word
  command[0] = command[0].upcase
  if(command.size >= 3)
    # Standardize formatting of amounts
    command[2].slice! "$"
    command[2] = "$%.2f" % command[2]
  end

  case command[0]
  when "BOUGHT" then buy(command)
  when "BUY" then buy(command)
  when "SOLD" then sell(command)
  when "SELL" then sell(command)
  when "RECENT" then recent(command)
  when "PAST" then recent(command)
  when "BALANCE" then balance(command)
  when "HELP" then help(command)
  else unknownCommand(command)
  end
end

def buy(command)
  puts "doing a buy"
  line = "Bought, #{command[1]}, #{command[2]}, #{Time.now}\n"
  File.open("out.csv", "a") {|f| f.write(line)}
  @t.say("Got your purchase: #{line}")
end

def sell(command)
  puts "doing a sell"
  line = "Sold, #{command[1]} (#{command[2]}), #{Time.now}\n"
  File.open("out.csv", "a") {|f| f.write(line)}
  @t.say("Got your sale: #{line}")
end

def recent(command)
  puts "replying with recent"
  lines = File.open("out.csv", "r").readlines
  if (lines.length > command[1].to_i)
    lines = lines[-command[1].to_i..-1]
  else
    lines = ["You requested too many entries!\n",
      "There are #{lines.length - 1} items in the ledger."]
  end


  @t.say(lines.join)
end

def balance(command)
  puts "got a balance request"
  @t.say("This is still being implemented.")
end

def unknownCommand(command)
  puts "unknownCommand - #{command.join(",")}"
  @t.say("Sorry, I couldn't understand your message. Please use following syntax: [command] [arguments]\nText HELP for available commands")
end

def help(command)
  puts "running help function"
  @t.say("The available commands are: BUY, SELL, RECENT, BALANCE")
end

