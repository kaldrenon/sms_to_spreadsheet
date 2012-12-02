# sms_to_spreadsheet

SMS to Spreadsheet is a Work-in-progress application for [RHoK-RIT](http://www.rhok.org/) and the [Peace Corps Innovation Challenge](http://innovationchallenge.peacecorps.gov/) ([link to specific challenge idea](http://innovationchallenge.peacecorps.gov/idea/27))

The objective of the application is to allow users to send SMS to a designated phone number, and the contents of the message will be parsed and used to update a spreadsheet. The spreadsheet will be a simple ledger (buy and sell entries).

## Project Status
In its current form, it is able to receive text messages, split and clean up extra spaces, and append to a CSV. It also sends limited feedback to users upon their request. Future development will result in more careful error detection, more user feedback, and simple configuration options. 

It also uses a whitelist file (whitelist.json) to limit influence over the spreadsheet to users who are approved.

## Using SMS to Spreadsheet
When the application is running, simply send a text message to the designated number.

Our current testing number is 585-326-0597.

The following commands can be used:

 * Buy: send a message formatted like `buy, item, amt` where `item` is what you bought and `amt` is the price you paid
 * Sell: send a message formatted like `sell, item, amt` where `item` is what you bought and `amt` is the amount you were given
 * Recent: send `recent, #` where `#` is the number of recent ledger entries you'd like to be sent.
 * Help: send `help` to be sent a reminder of the commands that can be used
 * Balance: *NOT YET IMPLEMENTED*, a planned feature is to notify the sender of the amounts spent and received within some time frame, as well as the available budget.


## Design

Basic workflow:
 * User sends text message
 * Check number against whitelist - send error message if # is not approved
 * Identify command in message (bought, sold/received, balance, report, etc)
 * send message body to appropriate method, process contents
 * update CSV or other files, send reply to user if needed

Important considerations:
 * texting is not free, should only reply or request a resend when necessary
 * strictly enforced syntax is not ideal, users likely non-technical, errors common in SMS
 * Only authorized users should be able to update or receive financial data

sms_to_spreadsheet uses Ruby Sinatra for the server and Tropo as an SMS gateway.
