module GoogleUser
  GOOGLE_OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token'

  def oauth_credentials_good?
    return false if self.oauth_access_token.nil?
    begin
      service = Google::Apis::Oauth2V2::Oauth2Service.new
      service.authorization = self.oauth_access_token
      # get_userinfo(fields: nil, quota_user: nil, user_ip: nil, options: nil) {|result, err| ... } ⇒ Google::Apis::Oauth2V2::Userinfoplus
      result = service.get_userinfo
      log "Oauth Credentials Good for #{self}", result
    rescue Google::Apis::AuthorizationError => e
      log "AuthorizationError", e
      false
    rescue
      raise $!
    end    
  end

  def ensure_oauth_credentials!
    if self.oauth_credentials_good?
      true
    elsif self.oauth_refresh_token
      self.refresh_oauth_token!
      self.oauth_credentials_good?
    else
      false
    end
  end

  def oauth_token_expired?
    self.oauth_expires_at < Time.zone.now
  end

  def oauth_clear!
    self.oauth_access_token = self.oauth_expires_at = nil
    self.save!
  end

  def oauth_revoke
    uri = URI('https://oauth2.googleapis.com/revoke')
    response = Net::HTTP.post_form(uri, 'token' => self.oauth_access_token)
    case response
    when Net::HTTPSuccess
      result = JSON.parse(response.body)
      log "Revoked oauth_token for #{self.to_s}", result
      self.oauth_clear!
    else
      self.oauth_clear!
      return false
    end
  end

  def oauth_tokeninfo
    begin
      service = Google::Apis::Oauth2V2::Oauth2Service.new
      service.authorization = self.oauth_access_token
      # get_userinfo(fields: nil, quota_user: nil, user_ip: nil, options: nil) {|result, err| ... } ⇒ Google::Apis::Oauth2V2::Userinfoplus
      result = service.tokeninfo(access_token: self.oauth_access_token)
      log "Oauth Token Info:", result
      true
    rescue Google::Apis::AuthorizationError => e
      log "AuthorizationError", e
      false
    rescue
      raise $!
    end    
  end

  def refresh_oauth_token!
    uri = URI(GOOGLE_OAUTH_TOKEN_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/x-www-form-urlencoded'

    request.body = URI.encode_www_form({
      client_id: AppConfig.google_client_id,
      client_secret: AppConfig.google_client_secret,
      refresh_token: self.oauth_refresh_token,
      grant_type: 'refresh_token'
    })

    response = http.request(request)
    case response
    when Net::HTTPSuccess
      result = JSON.parse(response.body)
      log 'refresh_oauth_token response', result
      if access_token = result['access_token'] 
        self.oauth_access_token = access_token
        if expires_in = result['expires_in']
          self.oauth_expires_at = Time.now.advance(seconds: expires_in.to_i)
        end
        if refresh_token = result['refresh_token']
          self.oauth_refresh_token = refresh_token
        end
        if self.changed?
          log "Refreshed oauth token: access token: #{self.oauth_access_token_changed? ? 'updated' : 'unchanged'}, refresh token: #{self.oauth_refresh_token_changed? ? 'updated' : 'unchanged'}, expires in #{expires_in} seconds"
          self.save! 
        end
      end
    else
      raise "Failed to refresh token: #{response.code} - #{response.body}"
    end
    true
  end

end