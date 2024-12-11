require 'nokogiri'

class GmailThreadParser
  include Plutolib::LoggerUtils
  def self.from_file(sub_path)
    path = Rails.root.join(sub_path)
    thread = Marshal.load(File.open(path).read)
    GmailThreadParser.new(gmail_thread: thread)
  end

  attr_accessor :gmail_thread

  def initialize(gmail_thread: nil, gmail_thread_id: nil)
    if gmail_thread
      @gmail_thread = gmail_thread
    elsif gmail_thread_id
      GmailServiceWrapper.use do |gmail|
        @gmail_thread = gmail.get_user_thread('me', gmail_thread_id)
      end
    end
  end

  def messages
    if @messages.nil?
      @messages = []
      self.each_message { |m| @messages.push(m) }
    end
    @messages
  end

  def each_message(&block)
    @gmail_thread.messages.each do |gmail_message| 
      block.yield(MessageWrapper.new(gmail_message))
    end
  end

  def received_datecode
    if internal_date = self.messages.first.try(:internal_date)
      received_time = Time.at(internal_date / 1000.0)
      received_time.strftime('%y%m%d')
    else
      '000000'
    end
  end
  def subject
    self.messages.first.try(:subject)
  end

  class MessageWrapper
    attr_accessor :mime_type
    attr_accessor :content
    attr_accessor :gmail_message
    def initialize(gmail_message)
      @gmail_message = gmail_message
      # @mime_type = ''
    end
    def label_names(labels_cache)
      @gmail_message.label_ids.map { |id| labels_cache[id].try(:name) || id }
    end
    def headers
      @headers ||= @gmail_message.payload.headers.select { |h| ['From', 'Date', 'Subject', 'To', 'Cc'].include?(h.name) }
    end 
    def subject
      @gmail_message.payload.headers.find { |h| h.name == 'Subject' }.try(:value)
    end

    def received_time
      Time.at(self.gmail_message.internal_date / 1000.0)
    end
    
    def text_data(html_to_text: true)
      @text_data ||= self.serialize_data(mime_type: 'text/plain', html_to_text: html_to_text)
    end

    def serialize_data(mime_type:, html_to_text: true)
      result = []
      self.each_data(mime_type: mime_type, html_to_text: html_to_text) { |data, payload| result.push(data) }
      result
    end

    def each_data(mime_type:, html_to_text:, &block)
      self.parse_message(@gmail_message.payload, mime_type: mime_type, html_to_text: html_to_text, &block)
    end

    def each_html_part(&block)
      self.parse_message(@gmail_message.payload, mime_type: 'text/html', &block)
    end

    def each_text_part(html_to_text: false, &block)
      self.parse_message(@gmail_message.payload, mime_type: 'text/plain', html_to_text: false, &block)
    end

    def parse_message(payload, mime_type: nil, html_to_text: nil, &block)
      if payload.mime_type == 'multipart/alternative'
        html_part = payload.parts.find { |pp| pp.mime_type == 'text/html' }
        text_part = payload.parts.find { |pp| pp.mime_type == 'text/plain' }
        if mime_type.nil? or (mime_type == 'text/plain')
          if text_part
            block.yield(text_part.body.data, text_part)
          elsif html_part and html_to_text
            block.yield(Nokogiri::HTML(html_part.body.data).text, html_part)
          end
        elsif mime_type == 'text/html'
          if html_part
            block.yield(html_part.body.data, html_part)
          end
        end
      elsif ['multipart/mixed', 'multipart/related'].include?(payload.mime_type)
        payload.parts.each do |pp|
          self.parse_message(pp, mime_type: mime_type, html_to_text: html_to_text, &block)
        end
      elsif ['text/plain', 'text/html'].include?(payload.mime_type)
        if mime_type.nil? or (mime_type == 'text/plain')
          block.yield(payload.body.data, payload)
        elsif (mime_type == 'text/html') and html_to_text
          block.yield(Nokogiri::HTML(payload.body.data).text, payload)
        end
      elsif payload.parts
        payload.parts.each do |part|
          self.parse_message(part, mime_type: mime_type, html_to_text: html_to_text, &block)
        end
      elsif mime_type.nil? or (mime_type == payload.mime_type)
        block.yield(payload.body.data, payload)
      end
    end
  end

  # GmailThreadParser.new.debug_thread(User.first, '1932b8cce68fa8b0')
  def debug_thread(user, thread_id)
    GmailServiceWrapper.ensure(user)
    log "Debugging thread #{thread_id}"
    result = nil
    GmailServiceWrapper.use do |gmail|
      result = gmail.get_user_thread('me', thread_id)
      debugger
      true
    end
  end

  def marshal_thread(user, thread_id, sub_path)
    GmailServiceWrapper.ensure(user)
    log "Marshalling thread #{thread_id}"
    thread = nil
    GmailServiceWrapper.use do |gmail|
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