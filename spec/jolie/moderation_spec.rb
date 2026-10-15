# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jolie::Moderation do
  describe ".moderate_link" do
    it "flags blocklisted hosts as BLACK_LIST with the matched entry" do
      result = described_class.moderate_link("https://sub.0-mail.com/page")

      expect(result).to be_flagged
      expect(result.source).to eq("https://sub.0-mail.com/page")
      expect(result.categories).to eq(["BLACK_LIST"])
      expect(result.moderation.first.matched).to eq("0-mail.com")
      expect(result.moderation.first.confidence).to eq(100)
    end

    it "flags shorteners as URL_SHORTENER unless they are allowed" do
      expect(described_class.moderate_link("https://bit.ly/x").categories).to eq(["URL_SHORTENER"])
      expect(described_class.moderate_link("https://bit.ly/x", allow_shorteners: true)).not_to be_flagged
    end

    it "reports nothing for ordinary links" do
      expect(described_class.moderate_link("https://example.com/")).not_to be_flagged
    end
  end

  describe ".link_blocked?" do
    it "is true for blocklisted hosts and false for clean ones" do
      expect(described_class.link_blocked?("someone@guerrillamail.com")).to be(true)
      expect(described_class.link_blocked?("someone@gmail.com")).to be(false)
    end
  end
end
