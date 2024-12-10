require 'rails_helper'

# nested_email.marshal structure:
# ============================================
# Subject: Re: SLO Broker
# -multipart/mixed
# --multipart/related
# ---multipart/alternative
# ----text/plain
# ----text/html
# ---image/png
# --application/pdf
# --application/pdf
# -multipart/related
# --multipart/alternative
# ---text/plain
# ---text/html
# --image/png
# --image/png

RSpec.describe GmailThreadParser, type: :lib do
  it 'Parses nested messages' do 
    # rails r "GmailThreadParser.new.marshal_thread(User.first, '1932b8cce68fa8b0', 'spec/data/nested_email.marshal')"
    gtp = GmailThreadParser.from_file('spec/data/nested_email.marshal')
    expect(gtp.gmail_thread).to be_truthy
    expect(gtp.messages.size).to eq(2)
    # First message:
    # -multipart/mixed
    # --multipart/related
    # ---multipart/alternative
    # ----text/plain
    # ----text/html
    # ---image/png
    # --application/pdf
    # --application/pdf
    message = gtp.messages[0]
    expect(message.text_data.size == 1)
    data = message.text_data.first
    expect(data.include?('Updated Docs attached.')).to be_truthy

    message = gtp.messages[1]
    expect(message.text_data.size == 1)
    data = message.text_data.first
    expect(data.include?('Thank you for these!')).to be_truthy
  end

  # ============================================
  # Subject: Re: Loan Application - 3543 Barron Way Fayetteville, NC 28311
  # Thread ID: 1935045dc89a2083
  # -multipart/mixed
  # --multipart/related
  # ---multipart/alternative
  # ----text/plain
  # ----text/html
  # ---image/jpeg
  # ---image/jpeg
  # --application/pdf
  # --application/pdf
  # -multipart/related
  # --multipart/alternative
  # ---text/plain
  # ---text/html
  # --image/jpeg
  # --image/jpeg
  it 'Parses multipart/mixed' do
    # rails r "GmailThreadParser.new.marshal_thread(User.first, '1935045dc89a2083', 'spec/data/multipart_example.marshal')"
    gtp = GmailThreadParser.from_file('spec/data/multipart_example.marshal')
    expect(gtp.gmail_thread).to be_truthy
    expect(gtp.messages.size).to eq(2)
    data = gtp.messages[0].text_data
    expect(data.size).to eq(1)
    expect(data.first.include?('Contract is attached.')).to be_truthy

    data = gtp.messages[1].text_data
    expect(data.size).to eq(1)
    expect(data.first.include?('My apologies.')).to be_truthy
  end
  it 'Can extract HTML from multipart/alternative' do
    gtp = GmailThreadParser.from_file('spec/data/multipart_example.marshal')
    expect(gtp.gmail_thread).to be_truthy
    expect(gtp.messages.size).to eq(2)
    data = gtp.messages[0].serialize_data(mime_type: 'text/html')
    expect(data.size).to eq(1)
    expect(data.first.include?('Contract is attached.</div>')).to be_truthy
  end
end
