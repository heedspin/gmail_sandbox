class Gm::Message
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
    @headers ||= @gmail_message.payload.headers.select { |h| ['from', 'date', 'subject', 'to', 'cc'].include?(h.name.downcase) }
  end 
  def subject
    @gmail_message.payload.headers.find { |h| h.name.downcase == 'subject' }.try(:value)
  end
  def message_id
    @gmail_message.payload.headers.find { |h| h.name.downcase == 'message-id' }.try(:value)
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
    elsif 'text/plain' == payload.mime_type
      if mime_type.nil? or (mime_type == 'text/plain')
        block.yield(payload.body.data, payload)
      end
    elsif 'text/html' == payload.mime_type
      if mime_type.nil? or (mime_type == 'text/html')
        block.yield(payload.body.data, payload)
      elsif (mime_type == 'text/plain') and html_to_text
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