require 'google/api_client'

  client = Google::APIClient.new
  key = Google::APIClient::PKCS12.load_key('pkey.p12', 'notasecret')
  service_account = Google::APIClient::JWTAsserter.new( '612889416699@developer.gserviceaccount.com', 'https://www.googleapis.com/auth/drive', key)
  client.authorization = service_account.authorize

  @@drive = client.discovered_api("drive", "v2")
  create_a_file(client)
  retrieve_all_files(client)

def print_file(client, file_id)
  result = client.execute(
    :api_method => @@drive.files.get,
    :parameters => { 'fileId' => file_id })
    if result.status == 200
      file = result.data
      puts "Title: #{file.title}"
      puts "Description: #{file.description}"
      puts "MIME type: #{file.mime_type}"
    else
      puts "An error occurred: #{result.data['error']['message']}"
    end
end

def retrieve_all_files(client)
  result = []
  api_result = client.execute(
    :api_method => @@drive.files.list
  )
  if api_result.status == 200
    puts "Success!"
    puts api_result.data.items
  else
    puts "Error: " + api_result.status.to_s
  end
end


def create_a_file(client)
  file = @@drive.files.insert.request_schema.new({
    'title' => "A New File",
    'description' => "It's new!"
  })

  result = client.execute(
    :api_method => @@drive.files.insert,
    :body_object => file,
    :parameters =>  {
      'uploadType' => 'multipart',
      'alt' => 'json'}
  )


end
