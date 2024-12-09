class GmailThreadParser
  include Plutolib::LoggerUtils
  include WithGoogleApi
  def self.from_file(sub_path)
    path = Rails.root.join(sub_path)
    thread = Marshal.load(File.open(path).read)
    GmailThreadParser.new(thread)
  end

  attr_accessor :gmail_thread
  attr_accessor :messages

  def initialize(gmail_thread)
    @gmail_thread = gmail_thread
    @messages = []
    self.parse
  end

  def received_datecode
    if internal_date = @messages.first.try(:internal_date)
      received_time = Time.at(internal_date / 1000.0)
      received_time.strftime('%y%m%d')
    else
      '000000'
    end
  end
  def subject
    header = @messages.first.headers.find { |h| h.name == 'Subject' }
    header.try(:value)
  end

  def parse
    @gmail_thread.messages.each do |gmail_message|
      message = Message.new(gmail_message)
      message.headers = gmail_message.payload.headers.select { |h| ['From', 'Date', 'Subject', 'To', 'Cc'].include?(h.name) }
      # "Headers=" + headers.map { |h| "#{h.name} #{h.value}" }.join("\n")
      if gmail_message.payload.parts
        self.flatten_parts(message, gmail_message.payload.parts)
      end 
      if gmail_message.payload.body
        message.maybe_set_content(gmail_message.payload)
      end
      @messages.push message
    end
    true
  end

  def flatten_parts(message, parts)
    parts.each do |part|
      message.maybe_set_content(part)
      if part.parts and (part.parts.size > 0)
        self.flatten_parts(message, part.parts)
      end
    end
  end

  class Message
    attr_accessor :headers
    attr_accessor :mime_type
    attr_accessor :content
    attr_accessor :gmail_message
    def initialize(gmail_message)
      @gmail_message = gmail_message
      @mime_type = ''
    end
    def label_names(labels_cache)
      @gmail_message.label_ids.map { |id| labels_cache[id].try(:name) || id }
    end
    def maybe_set_content(payload)
      return false unless payload.body.present? and payload.mime_type.present?
      if self.content.nil? or (self.mime_type != 'text/html')
        self.content = payload.body.data
        self.mime_type = payload.mime_type
        true
      else
        false
      end

    end
  end

  # LabelTraining::DownloadEmails.new(User.first).debug_thread('1932b8cce68fa8b0')
  def debug_thread(user, thread_id)
    gmail = Google::Apis::GmailV1::GmailService.new
    gmail.authorization = user.oauth_access_token
    log "Debugging thread #{thread_id}"
    result = nil
    with_google_api(user) do
      result = gmail.get_user_thread('me', thread_id)
      debugger
      true
    end
  end

  # rails r "LabelTraining::DownloadEmails.new(User.first).marshal_thread('1932b8cce68fa8b0', 'spec/parse_gmail/nested_email.marshal')"
  def marshal_thread(user, thread_id, sub_path)
    gmail = Google::Apis::GmailV1::GmailService.new
    gmail.authorization = user.oauth_access_token
    log "Marshalling thread #{thread_id}"
    thread = nil
    with_google_api(user) do
      thread = gmail.get_user_thread('me', thread_id)
    end
    destination_file_path = Rails.root.join(sub_path)
    File.open(destination_file_path, 'wb') do |file|
      Marshal.dump(thread, file)
    end
    log "Marshalled thread to #{destination_file_path}"
    true
  end

end