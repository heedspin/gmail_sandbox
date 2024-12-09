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
    gtp = GmailThreadParser.from_file('spec/lib/nested_email.marshal')
    expect(gtp.gmail_thread).to be_truthy
    expect(gtp.messages.size).to eq(2)
    expect(gtp.messages[0].mime_type).to eq('text/html')
    expect(gtp.messages[0].content.include?('Updated Docs attached.')).to be_truthy
    expect(gtp.messages[1].mime_type).to eq('text/html')
    expect(gtp.messages[1].content.include?('Thank you for these!')).to be_truthy
  end
end
