sms_to_spreadsheet
==================

SMS to Spreadsheet is a Work-in-progress application for RHoK-RIT

The objective of the application is to allow users to send SMS to a designated phone number, and the contents of the message will be parsed and used to update a spreadsheet.

In its current form, it is able to receive text messages, split and clean up extra spaces, and append to a CSV. Future development will result in more careful error detection, helpful user feedback, and simple configuration options. 

sms_to_spreadsheet uses Ruby Sinatra for the server and Tropo as an SMS gateway.
