class SynchronizeEmails
  include Plutolib::LoggerUtils
  def initialize(user)
    log_to_stdout
    @user = user
    Gm::Service.create(@user)
    @download_count = 0
  end

  # rails r "SynchronizeEmails.new(User.first).run"
  def run(limit: 100)
    last_history_id = Gm::MessageAction.by_history_id_desc.pluck(:history_id).first
    if last_history_id
      self.partial_sync(limit, last_history_id)
    else
      self.full_sync(limit)
    end
    Gm::MessageAction.older_than_a_week.destroy_all
  end

  def partial_sync(limit, last_history_id)    
    Gm::Service.instance.use do |gmail|
      page_token = nil
      begin
        result = gmail.list_user_histories('me', start_history_id: last_history_id, 
          max_results: 20, page_token: page_token,
          history_types: ['messageAdded'])
        if result.history
          result.history.each do |history|
            if history.messages_added
              history.messages_added.each do |hisory_message_added|
                self.synchronize_message(hisory_message_added.message)
                # self.synchronize_message(gmail, message_added)
                if (limit and ((@download_count += 1) >= limit))
                  log "Reached limit of #{limit}"
                  return true
                end
              end
            end
          end
          page_token = result.next_page_token
        end
      end while page_token
    end
    true
  end    

  def full_sync(limit)
    Gm::Service.instance.use do |gmail|
      page_token = nil
      begin
        result = gmail.list_user_messages('me', max_results: 20, page_token: page_token)
        result.messages.each do |gmail_message_ref|
          self.synchronize_message(gmail_message_ref)
          if (limit and ((@download_count += 1) >= limit))
            log "Reached limit of #{limit}"
            return true
          end
        end
        page_token = result.next_page_token
      end while page_token
    end
    true
  end

  # Snippet:
  # Google::Apis::GmailV1::Message:0x00007f79165a20d0
  # @id="1939db796fe35683",
  # @thread_id="1939cb351f17d8da">
  #
  # MINIMAL:
  # #<Google::Apis::GmailV1::Message:0x00007f1a6a6ceba8 
  # @history_id=20953905, 
  # @id="193ad387a09fb441", @internal_date=1733777976000, 
  # @label_ids=["IMPORTANT", "CATEGORY_PERSONAL"], 
  # @size_estimate=41550, 
  # @snippet="Thanks for the quick work today. Sent from my iPhone Begin forwarded message: From: Christy Musser &lt;christy.musser@homevestors.com&gt; Date: December 9, 2024 at 2:28:30 PM CST To: Morgan Byrd &lt;", @thread_id="193ad387a09fb441">
  def synchronize_message(gmail_message_ref)
    Gm::Service.instance.use do |gmail|
      # format: :MINIMAL: or :FULL
      result = gmail.get_user_message('me', gmail_message_ref.id, format: :MINIMAL)
      log "New message", result
      snippet = Gm::MessageAction.new(user: @user, 
        gmail_id: gmail_message_ref.id,
        history_id: result.history_id,
        internal_date: result.internal_date,
        label_ids: result.label_ids.to_json,
        snippet: result.snippet,
        actions: 'Create')
      snippet.save
    end
  end

end