class Gm::Service
	include Plutolib::LoggerUtils
	def self.create(user)
		@instance = Gm::Service.new(user)
	end
	def self.ensure(user)
		if @instance.nil?
			@instance = Gm::Service.new(user)
		end
	end
	def self.instance
		@instance
	end
	def self.use(&block)
		@instance.use(&block)
	end

	attr_accessor :gmail
	attr_accessor :user
	def initialize(user)
    @gmail = Google::Apis::GmailV1::GmailService.new
    @user = user
    @gmail.authorization = @user.oauth_access_token
	end

  def use(&block)
    if @user.oauth_expires_at < Time.now.to_datetime
      @user.refresh_oauth_token!
      @gmail.authorization = @user.oauth_access_token
    end
    begin
      yield(@gmail)
    rescue Google::Apis::AuthorizationError => e
      log "AuthorizationError.  Will refresh and retry"#, e
      @user.refresh_oauth_token!
      @gmail.authorization = @user.oauth_access_token
      yield(@gmail)
    rescue
      raise $!
    end
  end
end

# {"access_token"=>"ya29.a0AeDClZBYzNw4_-uiLzFwR7zCjNqOV5bqz0BdiKZ3spPTLc4Vp2rQyyfh1HhH5XC1IWiC04xgCI0tmJWwQCS47-9YEE_Y0FZWBlZlnmNJ0YQ1nDWm20AuLLgjUyK3kCz7L-rjXjiEPhyk2heEqd58jRcwjMzjq2_MSpOFUzKcaCgYKAXISARMSFQHGX2MihIN2c3pGADe-aWVRtHFfWg0175", 
# "expires_in"=>3599, 
# "scope"=>"openid https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/gmail.modify https://www.googleapis.com/auth/userinfo.email", 
# "token_type"=>"Bearer", 
# "id_token"=>"eyJhbGciOiJSUzI1NiIsImtpZCI6IjM2MjgyNTg2MDExMTNlNjU3NmE0NTMzNzM2NWZlOGI4OTczZDE2NzEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI2NjExNzI1MTc3NTUtY2NyZmxodGo2NjB0MDMwNDB2NHViOTIwaTVkbzhvNmouYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI2NjExNzI1MTc3NTUtY2NyZmxodGo2NjB0MDMwNDB2NHViOTIwaTVkbzhvNmouYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMDk0OTQ4NzMzMjQxOTQ1MTkzODIiLCJoZCI6Im9ha3dvb2RsZW5kaW5nLmNvbSIsImVtYWlsIjoidGltQG9ha3dvb2RsZW5kaW5nLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJhdF9oYXNoIjoiSEI0REp6MnotYjlWU2hDUGw0bDlXUSIsIm5hbWUiOiJUaW0gSGFycmlzb24iLCJwaWN0dXJlIjoiaHR0cHM6Ly9saDMuZ29vZ2xldXNlcmNvbnRlbnQuY29tL2EvQUNnOG9jS3V5REZPUGFjUFZ3ZzdldmQ4NXA4SFlOTkdtVlphRnNRUWtiTkxHQmptTER6NHVnMD1zOTYtYyIsImdpdmVuX25hbWUiOiJUaW0iLCJmYW1pbHlfbmFtZSI6IkhhcnJpc29uIiwiaWF0IjoxNzMyNjUyMjgwLCJleHAiOjE3MzI2NTU4ODB9.pElp0inQHC8ugazsXUq-lzYkMi66KROlkBx6ZY6qkW1u1dngPH-jyAKgox-zdNcXb-S5uJNeXjIyNsJ5RjlE_f6VpGJGC8B289LRgF3MqR5MUzv8tZEmCL67GWgoV7PJHZ3YoIoDVq9bUv4rZmA2zE1j9GWQVs25XrG-0wYxhfn5rruXwlQqSOvePcfBQD3bvGX1p5140eF5JKeSnoKC8JpRsa1F6KhYN5SxheG4EasHVrRD4K1WJEz9PVfGvHZTFTIgKogFblF4z_FZOjedv6cakKjZKh-
