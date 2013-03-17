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
@@admin = c['admin']
ENV['MONGODB_URI'] = c['db']['uri']
@@mongo = MongoClient.new
# These are documents in the Mongo DB
@@apps = @@mongo['pcsms']['applications']
@@white = @@mongo['pcsms']['whitelist']
@@ledgers = @@mongo['pcsms']['ledgers']

Pony.options = {
  :via => :smtp,
  :via_options => {
    :address => 'smtp.sendgrid.net',
    :port => '587',
    :domain => 'heroku.com',
    :user_name => ENV['SENDGRID_USERNAME'],
    :password => ENV['SENDGRID_PASSWORD'],
    :authentication => :plain,
    :enable_starttls_auto => true
  }
}

use Rack::Session::Pool

post '/index.json' do
  # Receive a text message from an external device
  @v = Tropo::Generator.parse request.env["rack.input"].read
  @t = Tropo::Generator.new

  # Pull important values out of the Tropo-generated JSON blob
  @sender = @v[:session][:from][:id]
  @message_text = @v[:session][:initial_text]

  # Check for sender number in whitelist
  if (@@white.find("number" => @sender).count == 1)
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
  when "RECENT" then recent()
  when "PAST" then recent()
  when "BALANCE" then balance
  when "HELP" then help
  when "REGISTER" then register(command)
  else unknownCommand
  end
end

### Add record of a buy to the ledger
def buy(command)
  action = "Bought"
  description = command[1]
  value = "(#{command[2]})"
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
def recent
  num_recent = 5
  entries = @@ledgers.find("owner" => @sender).first['entries']

  if(entries.length < num_recent)
    num_recent = entries.length
  end

  reply = ["Most recent ledger entries:"]
  
  for n in 1..num_recent
    entry = entries[-n]
    reply.push("#{entry['action']}, #{entry['description']}, #{entry['value']}")
  end

  @t.say(reply.join("\n"))
end

### Calculate the balance based on sum/difference of all ledger entries
def balance
  entries = @@ledgers.find("owner" => @sender).first['entries']

  sum = 0
  entries.each do |entry|
    value = entry['value'].gsub("$","")

    if entry['value'][0] == '('
      value = value[1..-2]
      sum = sum - value.to_i
    else
      sum = sum + value.to_i
    end
  end

  @t.say("The balance is $#{sum}")
end

### Let user know their request wasn't understood.
def unknownCommand
  @t.say("Sorry, I couldn't understand your message. Please use following syntax: [command] [arguments]\nText HELP for available commands")
end

### Show user a help message
def help
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
  ledger = params[:ledger]

  # TODO: Update Mongo applications document
  @@apps.insert({"name" => name, "email" => email, "number" => number, "ledger" => ledger})

  #TODO: Email admin about a new request
  Pony.mail(
    :to => @@admin,
    :from => "csv_sender@pcsms.herokuapp.com",
    :subject => "New Applicant on PCSMS - #{name}",
    :html_body => "<a href=\"http://pcsms.herokuapp.com\">Click here!</a>"
  )
end

def build_csv(number)
  ledger = @@ledgers.find("owner" => number).first
  entries = ledger['entries']

  body = [ledger['title'], "", "Action,Description,Value,Time"]

  entries.each do |entry|
    body.push("#{entry['action']},#{entry['description']},#{entry['value']},#{entry['timestamp']}")
  end

  return body.join("\n")
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

  post = false
  sender_info = @@white.find("number" => number)
  if(sender_info.count > 0)
    sender_info = sender_info.first
    ledger_name = @@ledgers.find("owner" => sender_info['number']).first['title']
    if(sender_info['email'] == email)
      attachment = "#{ledger_name}.csv"

      csv_body = build_csv(number)


      Pony.mail(
        :to => "#{sender_info['name']} <#{email}>",
        :from => "csv_sender@pcsms.herokuapp.com",
        :subject => sender_info['name'] + ", here is the email you requested from S2S.",
        :html_body => "See attachment.",
        :attachments => {File.basename("#{attachment}") => csv_body}
      )
      post = true

      erb :email_request, :locals => {
        :sent => true, 
        :post => post, 
        :number => number, 
        :email => email,
        :name => sender_info['name']
      }
    else
      return "<h3>failed</h3>"
    end
  else
    return "#{@@white.find("number" => number).to_s}"
  end

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

get '/admin' do
  erb :admin
end

post '/admin_panel' do
  admin_pw = @@mongo['pcsms']['admin'].find("context" => "dev").first["pw"]
  puts params[:pw]
  if params[:pw] == admin_pw
    "<h3>Logged in!</h3>"
  end
end

