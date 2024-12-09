# ExportEmailStructure.new(User.first).run('1OWL24/SLO - 826 S 5th St, Smithfield, NC 27577', limit: 100)
class ExportEmailStructure
  include Plutolib::LoggerUtils
  include WithGoogleApi
  def initialize(user)
    log_to_stdout
    @user = user
    @gmail = Google::Apis::GmailV1::GmailService.new
    @gmail.authorization = @user.oauth_access_token
    @labels_cache = {}
    @destination_file_path = Rails.root.join('log/email_structure.txt')
  end

  def run(label_name, limit: nil)
    unless @user.ensure_oauth_credentials!
      log "Failed to authorize user"
      return false
    end
    download_count = 0
    labels = GmailLabels.new(@user).user_labels(label_name)
    log "Got #{labels.size} labels for #{@user}"
    label = labels.first
    File.open(@destination_file_path, 'w') do |file|
      file.puts "Label: #{label_name}"
    end
    result = nil
    with_google_api(@user) do
      page_token = nil
      begin
        result = @gmail.list_user_threads('me', label_ids: [label.id], max_results: 10, page_token: page_token)
        result.threads.each do |gmail_thread_snippet|
          gmail_thread = @gmail.get_user_thread('me', gmail_thread_snippet.id)          
          subject = gmail_thread.messages.first.payload.headers.find { |h| h.name == 'Subject' }
          self.write_structure("============================================\n", "Subject: #{subject.try(:value) || 'unknown'}")
          self.parse_thread_structure(gmail_thread)
          download_count += 1
          if (limit and (download_count >= limit))
            log "Reached limit of #{limit}"
            return true
          end
        end
        page_token = result.next_page_token
      end while page_token
    end
    true
  end

  def write_structure(thing1, thing2)
    File.open(@destination_file_path, 'a') do |file|
      file.puts "#{thing1}#{thing2}"
    end
  end

  def parse_thread_structure(gmail_thread)
    gmail_thread.messages.each do |gmail_message|
      if gmail_message.payload.body
        self.write_structure('-', gmail_message.payload.mime_type)
      end
      if gmail_message.payload.parts
        self.flatten_parts('--', gmail_message.payload.parts)
      end 
    end
    true
  end

  def flatten_parts(tabs, parts)
    parts.each do |part|
      self.write_structure(tabs, part.mime_type)
      if part.parts and (part.parts.size > 0)
        self.flatten_parts(tabs + '-', part.parts)
      end
    end
  end

end