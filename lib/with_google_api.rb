require 'net/http'
require 'json'

module WithGoogleApi
  GOOGLE_OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token'

  def with_google_api(user, &block)
    if user.oauth_expires_at < Time.now.to_datetime
      self.refresh_oauth_token(user)
    end
    begin
      yield
    rescue Google::Apis::AuthorizationError => e
      log "AuthorizationError", e
      self.refresh_oauth_token(user)
      yield
    rescue
      raise $!
    end
  end

  def refresh_oauth_token(user)
    uri = URI(GOOGLE_OAUTH_TOKEN_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/x-www-form-urlencoded'

    request.body = URI.encode_www_form({
      client_id: AppConfig.google_client_id,
      client_secret: AppConfig.google_client_secret,
      refresh_token: user.oauth_refresh_token,
      grant_type: 'refresh_token'
    })

    response = http.request(request)
    case response
    when Net::HTTPSuccess
      result = JSON.parse(response.body)
      log 'refresh_oauth_token response', result
      if access_token = result['access_token'] 
        user.oauth_access_token = access_token
        if expires_in = result['expires_in']
          user.oauth_expires_at = Time.now.advance(seconds: expires_in.to_i)
        end
        if refresh_token = result['refresh_token']
          user.oauth_refresh_token = refresh_token
        end
        if user.changed?
          log "Refreshed oauth token: access token: #{user.oauth_access_token_changed? ? 'updated' : 'unchanged'}, refresh token: #{user.oauth_refresh_token_changed? ? 'updated' : 'unchanged'}, expires in #{expires_in} seconds"
          user.save! 
        end
      end
    else
      raise "Failed to refresh token: #{response.code} - #{response.body}"
    end
    true
  end
end

# {"access_token"=>"ya29.a0AeDClZBYzNw4_-uiLzFwR7zCjNqOV5bqz0BdiKZ3spPTLc4Vp2rQyyfh1HhH5XC1IWiC04xgCI0tmJWwQCS47-9YEE_Y0FZWBlZlnmNJ0YQ1nDWm20AuLLgjUyK3kCz7L-rjXjiEPhyk2heEqd58jRcwjMzjq2_MSpOFUzKcaCgYKAXISARMSFQHGX2MihIN2c3pGADe-aWVRtHFfWg0175", 
# "expires_in"=>3599, 
# "scope"=>"openid https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/gmail.modify https://www.googleapis.com/auth/userinfo.email", 
# "token_type"=>"Bearer", 
# "id_token"=>"eyJhbGciOiJSUzI1NiIsImtpZCI6IjM2MjgyNTg2MDExMTNlNjU3NmE0NTMzNzM2NWZlOGI4OTczZDE2NzEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI2NjExNzI1MTc3NTUtY2NyZmxodGo2NjB0MDMwNDB2NHViOTIwaTVkbzhvNmouYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI2NjExNzI1MTc3NTUtY2NyZmxodGo2NjB0MDMwNDB2NHViOTIwaTVkbzhvNmouYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMDk0OTQ4NzMzMjQxOTQ1MTkzODIiLCJoZCI6Im9ha3dvb2RsZW5kaW5nLmNvbSIsImVtYWlsIjoidGltQG9ha3dvb2RsZW5kaW5nLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJhdF9oYXNoIjoiSEI0REp6MnotYjlWU2hDUGw0bDlXUSIsIm5hbWUiOiJUaW0gSGFycmlzb24iLCJwaWN0dXJlIjoiaHR0cHM6Ly9saDMuZ29vZ2xldXNlcmNvbnRlbnQuY29tL2EvQUNnOG9jS3V5REZPUGFjUFZ3ZzdldmQ4NXA4SFlOTkdtVlphRnNRUWtiTkxHQmptTER6NHVnMD1zOTYtYyIsImdpdmVuX25hbWUiOiJUaW0iLCJmYW1pbHlfbmFtZSI6IkhhcnJpc29uIiwiaWF0IjoxNzMyNjUyMjgwLCJleHAiOjE3MzI2NTU4ODB9.pElp0inQHC8ugazsXUq-lzYkMi66KROlkBx6ZY6qkW1u1dngPH-jyAKgox-zdNcXb-S5uJNeXjIyNsJ5RjlE_f6VpGJGC8B289LRgF3MqR5MUzv8tZEmCL67GWgoV7PJHZ3YoIoDVq9bUv4rZmA2zE1j9GWQVs25XrG-0wYxhfn5rruXwlQqSOvePcfBQD3bvGX1p5140eF5JKeSnoKC8JpRsa1F6KhYN5SxheG4EasHVrRD4K1WJEz9PVfGvHZTFTIgKogFblF4z_FZOjedv6cakKjZKh-