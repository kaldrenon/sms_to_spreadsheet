sms_to_spreadsheet
==================

SMS to Spreadsheet is a Work-in-progress application for RHoK-RIT

The objective of the application is to allow users to send SMS to a designated phone number, and the contents of the message will be parsed and used to update a spreadsheet.

In its current form, it is able to receive text messages, split and clean up extra spaces, and append to a CSV. Future development will result in more careful error detection, helpful user feedback, and simple configuration options. 

sms_to_spreadsheet uses Ruby Sinatra for the server and Tropo as an SMS gateway.


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

