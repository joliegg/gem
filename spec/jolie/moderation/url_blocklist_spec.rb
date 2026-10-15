# frozen_string_literal: true

require "spec_helper"

# Sentinel entries verified against the bundled data: "0-mail.com",
# "mailinator.com", "10minutemail.com" and "guerrillamail.com" are blocklisted;
# "bit.ly" and "tinyurl.com" are shorteners; "gmail.com" and "example.com"
# appear on neither list.
RSpec.describe Jolie::Moderation::UrlBlocklist do
  subject(:blocklist) { described_class }

  describe ".extract_host" do
    it "reduces full URLs to their host" do
      expect(blocklist.extract_host("https://Sub.Example.COM:8443/some/path?x=1#frag")).to eq("sub.example.com")
    end

    it "accepts bare domains, with or without a trailing root dot" do
      expect(blocklist.extract_host("Example.COM")).to eq("example.com")
      expect(blocklist.extract_host("example.com.")).to eq("example.com")
    end

    it "takes the domain side of email addresses" do
      expect(blocklist.extract_host("Someone@Example.COM")).to eq("example.com")
    end

    it "recognizes emails whose local part contains URL delimiter characters" do
      # / ? # are valid in an RFC 5322 local part; they must not sever the domain.
      expect(blocklist.extract_host("a/b@mailinator.com")).to eq("mailinator.com")
      expect(blocklist.extract_host("a?b#c@mailinator.com")).to eq("mailinator.com")
    end

    it "prefers the host over URL userinfo" do
      expect(blocklist.extract_host("https://example.com@evil.example/")).to eq("evil.example")
    end

    it "returns \"\" for blank and non-host input" do
      expect(blocklist.extract_host(nil)).to eq("")
      expect(blocklist.extract_host("   ")).to eq("")
    end
  end

  describe ".blocked? / .match" do
    it "matches listed domains given as a URL, bare domain, or email" do
      expect(blocklist).to be_blocked("https://mailinator.com/inbox")
      expect(blocklist).to be_blocked("mailinator.com")
      expect(blocklist).to be_blocked("someone@mailinator.com")
    end

    it "matches any subdomain of a listed domain" do
      expect(blocklist).to be_blocked("deep.sub.domain.0-mail.com")
      expect(blocklist.match("deep.sub.domain.0-mail.com")).to eq("0-mail.com")
    end

    it "matches case-insensitively and past ports, paths, and trailing dots" do
      expect(blocklist).to be_blocked("HTTPS://MAILINATOR.COM.:443/a?b=1")
    end

    it "does not match unlisted domains, parents, or lookalikes" do
      expect(blocklist).not_to be_blocked("gmail.com")
      expect(blocklist).not_to be_blocked("fakemailinator.io")
      expect(blocklist).not_to be_blocked("mailinator.com.evil.example")
    end

    it "does not match blank or malformed input" do
      expect(blocklist).not_to be_blocked(nil)
      expect(blocklist).not_to be_blocked("")
      expect(blocklist).not_to be_blocked("http://")
    end

    it "only treats an @ inside the authority as userinfo" do
      # The @ is in the query — the host is still the blocklisted one.
      expect(blocklist).to be_blocked("https://mailinator.com/path?next=user@example.com")
      # …and a blocklisted domain buried in the query must not condemn a clean host.
      expect(blocklist).not_to be_blocked("https://example.com/redirect?to=user@mailinator.com")
    end

    it "cannot be bypassed with URL delimiter characters in an email local part" do
      expect(blocklist).to be_blocked("a/b@mailinator.com")
      expect(blocklist).to be_blocked("a?b#c@0-mail.com")
      # Fail-closed on purpose: a schemeless string with an @ is read as an
      # email, so a blocklisted domain after the @ decides even inside a
      # would-be URL (the scheme-bearing form above stays clean).
      expect(blocklist).to be_blocked("example.com/redirect?to=user@mailinator.com")
    end
  end

  describe ".shortener? / .matched_shortener" do
    it "matches listed shorteners" do
      expect(blocklist).to be_shortener("https://bit.ly/abc123")
      expect(blocklist).to be_shortener("tinyurl.com")
    end

    it "suffix-matches subdomains of a listed shortener" do
      expect(blocklist.matched_shortener("links.bit.ly")).to eq("bit.ly")
    end

    it "does not match ordinary domains" do
      expect(blocklist).not_to be_shortener("example.com")
      expect(blocklist).not_to be_shortener("bit.ly.evil.example")
    end
  end

  describe "bundled data" do
    it "loads both lists at their expected sizes" do
      expect(blocklist.blocklist_size).to be > 100_000
      expect(blocklist.shortener_size).to be > 1_000
    end
  end
end
