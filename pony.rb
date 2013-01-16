require 'rubygems'
require 'pony'

filename = "out.csv"
filebody = File.read("out.csv")

puts "file is read, mailing..."

Pony.mail(
  :to => "kaldrenon@gmail.com",
  :from => "kaldrenon@gmail.com",
  :subject => "Andrew, here is the email you requested from S2S.",
  :html_body => "See attachment.",
  #:attachments => {filename => filebody},
  #:headers => { "Content-Type" => "multipart/mixed", "Content-Transfer-Encoding" => "base64", "Content-Disposition" => "attachment" },
  :via => :smtp,
  :via_options => {
    :address => 'smtp.gmail.com',
    :port => 465,
    :user_name => "kaldrenon@gmail.com",
    :password => "Rz7cU6B8JCsz7125",
    :enable_starttls_auto => true
  }
)

puts "mail sent"
