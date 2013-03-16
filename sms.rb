#RHoK 
require 'sinatra'
require 'json'
require 'rubygems'
require 'tropo-webapi-ruby'
require 'pony'
require 'mongo'

### Mongo includes
include Mongo

c = JSON.parse(File.open("config.json","r").read)
ENV['MONGODB_URI'] = c['db']['uri']
@@mongo = MongoClient.new
# These are documents in the Mongo DB
@@apps = @@mongo['pcsms']['applications']
@@white = @@mongo['pcsms']['whitelist']
@@ledgers = @@mongo['pcsms']['ledgers']

use Rack::Session::Pool

post '/index.json' do
  # Receive a text message from an external device
  @v = Tropo::Generator.parse request.env["rack.input"].read
  @t = Tropo::Generator.new

  # Pull important values out of the Tropo-generated JSON blob
  @sender = @v[:session][:from][:id]
  @message_text = @v[:session][:initial_text]

  # Check for sender number in whitelist
  if (@@white.find("number" => @sender))
    # Find this user's ledger.
    @ledger = @@white.find("number" => @sender).first['ledger']

    performAction(@message_text)
  else
    @t.say("Your number is not recognized in our approved list.")
  end

  # Write the message to a document in mongo
  @@mongo['pcsms']['message_dump'].insert({"message" => @message_text, "sender" => @sender})

  return @t.response
end

# Currently - command: 0 = keyword, 1 = item, 2 = value. For recent, 1 = qty
# TODO: Make this more robust for commands of varying length
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
  when "REGISTER" then register(command)
  else unknownCommand(command)
  end
end

### Add record of a buy to the ledger
def buy(command)
  action = "Bought"
  description = command[1]
  value = command[2]
  timestamp = Time.now.to_s
  @t.say("Got your purchase: #{action}, #{description}, #{value}")
  
  ledger_push(action, value, description, timestamp)
  
end

### Add record of a sale to the ledger
def sell(command)
  action = "Sold"
  description = command[1]
  value = command[2]
  timestamp = Time.now.to_s
  @t.say("Got your sale: #{action}, #{description}, #{value}")
  
  ledger_push(action, value, description, timestamp)
end

def ledger_push(action, value, description, timestamp)
  # TODO: Check if ledger exists first
  @@ledgers.update(
    {"owner" => @sender}, 
    { "$push" => 
      { "entries" => 
        {
          "action" => action, 
          "value" => value, 
          "description" => description, 
          "timestamp" => timestamp
        } 
      }
    }
  )
end

### Show the user the N most recent transactions
def recent(command)
  # TODO: Replace file operations with db operations
  lines = File.open("out.csv", "r").readlines
  if (lines.length > command[1].to_i)
    lines = lines[-command[1].to_i..-1]
  else
    lines = ["You requested too many entries!\n",
      "There are #{lines.length - 1} items in the ledger."]
  end
  @t.say(lines.join("\n"))
end

### Calculate the balance based on sum/difference of all ledger entries
def balance(command)
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

  @t.say("The balance is $#{sum}")
end

### Let user know their request wasn't understood.
def unknownCommand(command)
  @t.say("Sorry, I couldn't understand your message. Please use following syntax: [command] [arguments]\nText HELP for available commands")
end

### Show user a help message
def help(command)
  @t.say("The available commands are: BUY, SELL, RECENT, BALANCE")
end

### TODO: Let a user register via SMS
def register(command)
  args = command.split(" ")[1..-1]
  params = { :name => args[0], :number => args[1], :email => args[2] }
  add_application(params)
end

def add_application(params)
  name = params[:name]
  email = params[:email]
  number = params[:number]

  json = JSON.parse(File.open("applications.json","r").read)
  json[number] = {"name" => name, "email" => email}

  # TODO: Update Mongo applications document
  #File.open("applications.json","w") do |f|
  #  f.write(JSON.pretty_generate(json))
  #end

  #TODO: Email admin about a new request
end

### Show an index page (explains the purpose of the app)
get '/' do
  erb :index
end

### Show a form letting a user request an emailed CSV
get '/email' do
  erb :email_request, :locals => {:sent => false, :post => false}
end

### If the input was valid, send the user the CSV they requested
post '/email' do
  number = params[:number]
  email = params[:email]
  
  json = File.open("whitelist.json","r").read
  @whitelist = JSON.parse(json)

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

### Show a form for registering in the system
get '/register' do
  erb :register, :locals => { :post => false }
end

### Create an application for the admin to approve
post '/register' do
  add_application(params)
  erb :register, :locals => { :post => true }
end

