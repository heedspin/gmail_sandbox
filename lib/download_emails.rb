# DownloadEmails.new(User.first).run('1OWL24', limit: 500)
class DownloadEmails
  include Plutolib::LoggerUtils
  def initialize(user)
    log_to_stdout
    @user = user
    Gm::Service.create(@user)
    @labels_cache = {}
  end

  def run(labels_that_start_with, limit: nil)
    unless @user.ensure_oauth_credentials!
      log "Failed to authorize user"
      return false
    end
    download_count = 0
    labels = GmailLabels.new(@user).user_labels(labels_that_start_with)
    log "Got #{labels.size} labels for #{@user}"
    labels.each do |label|
      @labels_cache[label.id] = label
    end
    labels.each do |label|
      # next if label.name == labels_that_start_with # Skip top level
      # parts = label.name.split('/')
      # if parts.size != 2
      #   log_error "Skipping unexpected label: #{label.name}"
      #   next
      # end

      result = nil
      Gm::Service.instance.use do |gmail|
        #list_user_threads(user_id, include_spam_trash: nil, label_ids: nil, max_results: nil, page_token: nil, q: nil, fields: nil, quota_user: nil, user_ip: nil, options: nil) {|result, err| ... } ⇒ Google::Apis::GmailV1::ListThreadsResponse
        page_token = nil
        begin
          result = gmail.list_user_threads('me', label_ids: [label.id], max_results: 10, page_token: page_token)
          result.threads.each do |thread_snippet|
            log "Downloading thread #{thread_snippet.id}"
            thread_parser = Gm::ThreadParser.new(gmail_thread_id: thread_snippet.id)
            self.save_thread(label, thread_parser)
            download_count += 1
            if (limit and (download_count >= limit))
              log "Reached limit of #{limit}"
              return true
            end
          end
          page_token = result.next_page_token
        end while page_token
      end
    end
    true
  end

  def utf8_encode(text)
    if text.encoding == Encoding::UTF_8
      text
    else
      text.force_encoding('UTF-8')
      # text.encode('UTF-8', 'ASCII-8BIT', invalid: :replace, undef: :replace)
    end
  end

  def save_thread(label, thread_parser)
    destination_folder = self.ensure_subfolder(label.name.parameterize)
    destination_filename = "#{thread_parser.gmail_thread.id} #{thread_parser.subject}".parameterize
    destination_file_path = File.join(destination_folder, destination_filename) + '.txt'
    File.open(destination_file_path, 'w') do |file|
      file.puts '========================================================'
      file.puts("Gmail Thread ID: #{thread_parser.gmail_thread.id}")
      thread_parser.each_message do |message_wrapper|
        self.save_message(destination_folder, message_wrapper)
        file.puts '========================================================'
        file.puts("Gmail Message ID: #{message_wrapper.gmail_message.id}")
        message_wrapper.headers.each do |header|
          file.puts("#{header.name}: #{utf8_encode header.value}")
        end
        message_wrapper.each_data(mime_type: 'text/plain', html_to_text: true) do |data, payload|
          file.puts(utf8_encode data || 'empty message, wut...')
        end
      end
    end
    log "Wrote #{destination_file_path}"
    true
  end

  def save_message(thread_folder, message_wrapper)
    destination_folder = self.ensure_subfolder(thread_folder, message_wrapper.subject.parameterize)
    destination_filename = "#{message_wrapper.received_time} #{message_wrapper.gmail_message.id}"
    destination_file_path = File.join(destination_folder, destination_filename) + '.txt'
    File.open(destination_file_path, 'w') do |file|
      file.puts '========================================================'
      file.puts("Gmail ID: #{message_wrapper.gmail_message.id}")
      file.puts("Gmail Message-ID: #{message_wrapper.message_id}")
      message_wrapper.headers.each do |header|
        file.puts("#{header.name}: #{utf8_encode header.value}")
      end
      message_wrapper.each_data(mime_type: 'text/plain', html_to_text: true) do |data, payload|
        file.puts(utf8_encode data || 'empty message, wut...')
      end
    end
    log "Wrote #{destination_file_path}"    
  end

  def ensure_subfolder(*parts)
    path = Rails.root.join('storage', 'emails', *parts)
    if !Dir.exist?(path)
      FileUtils.mkdir_p(path)
    end
    path
  end
end