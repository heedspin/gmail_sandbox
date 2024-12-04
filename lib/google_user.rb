module GoogleUser

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

end