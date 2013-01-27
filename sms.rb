#RHoK 
require 'sinatra'
require 'rubygems'
require 'tropo-webapi-ruby'
require 'pony'

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

  File.open("numbers","a") {|f| f.write(@sender + "\n")}

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
    @t.say("Your number is not recognized in our approved list.")
  end

  puts "From: #{@sender}"
  puts "Body: #{@message_text}"

  # Write the line to a CSV
  File.open("test.csv", "a") {|f| f.write(@message_text + "\n")}

  return @t.response
end

# command: 0 = keyword, 1 = item, 2 = value. For recent, 1 = qty
def performAction(command)
  command = command.strip.split(/ *, */)
  # Force upper case for the command word
  command[0] = command[0].upcase
  if(command.size >= 3)
    # Standardize formatting of amounts
    command[2].slice! "$"
    command[2] = "$%.2f" % command[2]
  end

  # Execute the appropriate command based on the first word in the message
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

# Add record of a buy to the CSV
def buy(command)
  puts "doing a buy"
  line = "Bought, #{command[1]}, (#{command[2]})"
  @t.say("Got your purchase: #{line}")
  line = line + ", #{Time.now}\n"
  File.open("out.csv", "a") {|f| f.write(line)}
end

# Add record of a sale to the CSV
def sell(command)
  puts "doing a sell"
  line = "Sold, #{command[1]}, #{command[2]}"
  @t.say("Got your sale: #{line}")
  line = line + ", #{Time.now}\n"
  File.open("out.csv", "a") {|f| f.write(line)}
end

# Show the user the N most recent transactions
def recent(command)
  puts "replying with recent"
  lines = File.open("out.csv", "r").readlines
  if (lines.length > command[1].to_i)
    lines = lines[-command[1].to_i..-1]
  else
    lines = ["You requested too many entries!\n",
      "There are #{lines.length - 1} items in the ledger."]
  end
  puts lines.join("\n")
  @t.say(lines.join("\n"))
end

def balance(command)
  puts "got a balance request"
  valuesArray = []
  lines = File.open("out.csv", "r").readlines.each do |line|
    line = line.split(/ *, */)
    valuesArray.push(line[2])
  end
  sum = 0
  valuesArray.each do |value|
    if value[0] == '('
      value = value[2..-2]
      sum = sum - value.to_i
    else
      value = value[1..-1]
      sum = sum + value.to_i
    end
  end
  puts "The sum is: #{sum}"

  @t.say("The balance is $#{sum}")
end

# Let user know their request wasn't understood.
def unknownCommand(command)
  puts "unknownCommand - #{command.join(",")}"
  @t.say("Sorry, I couldn't understand your message. Please use following syntax: [command] [arguments]\nText HELP for available commands")
end

# Show user a help message
def help(command)
  puts "running help function"
  @t.say("The available commands are: BUY, SELL, RECENT, BALANCE")
end


get '/' do
  erb :index
end

get '/email' do
  erb :email_request, :locals => {:sent => false, :post => false}
end

post '/email' do
  number = params[:number]
  email = params[:email]
  
  puts params

  json = File.open("whitelist.json","r").read
  @whitelist = JSON.parse(json)
  puts @whitelist

  post = false
  if (@whitelist[number]["email"]) and (@whitelist[number]["email"] == email)
    attachment = "out.csv"
    Pony.mail(
      :to => "#{@whitelist[number]["name"]} <#{email}>",
      :from => 'SMS to Spreadsheet <s2s@kaldrenon.com>',
      :subject => @whitelist[number]["name"] + ", here is the email you requested from S2S.",
      :html_body => "See attachment.",
      :attachments => {File.basename("#{attachment}") => File.read("#{attachment}")}
    )
    post = true
  end


  erb :email_request, :locals => {
    :sent => true, 
    :post => post, 
    :number => number, 
    :email => email,
    :name => @whitelist[number]["name"]
  }
end

get '/register' do
  erb :register, :locals => { :post => false }
end

post '/register' do
  name = params[:name]
  email = params[:email]
  number = params[:number]

  json = JSON.parse(File.open("applications.json","r").read)
  json[number] = {"name" => name, "email" => email}

  File.open("applications.json","w") do |f|
    f.write(JSON.pretty_generate(json))
  end

  erb :register, :locals => { :post => true }
end

