# frozen_string_literal: true

require "json"

module Jolie
  module Moderation
    # Domain blocklist and URL-shortener list extracted from the
    # @joliegg/moderation TypeScript package: data/url_blacklist.json and
    # data/url_shorteners.json are verbatim copies of that repo's
    # src/url-blacklist.json / src/url-shorteners.json (run
    # `rake "data:sync[/path/to/moderation]"` to refresh them).
    #
    # Matching mirrors ModerationClient#moderateLink: an input (full URL, bare
    # domain, or email address) is reduced to its host, then every domain
    # suffix is checked against the set — a listed "example.com" also blocks
    # "sub.example.com", and an email at either address is blocked. Unlike the
    # TS package's exact-match shortener check, shorteners are suffix-matched
    # too, so "links.bit.ly" is recognized when "bit.ly" is listed.
    module UrlBlocklist
      DATA_DIR = File.expand_path("../../../data", __dir__).freeze
      BLOCKLIST_PATH = File.join(DATA_DIR, "url_blacklist.json").freeze
      SHORTENERS_PATH = File.join(DATA_DIR, "url_shorteners.json").freeze

      module_function

      # True when the input's host (or any parent domain of it) is blocklisted.
      def blocked?(input)
        !match(input).nil?
      end

      # The blocklist entry that matched the input's host, or nil.
      def match(input)
        find_in(blocklist, input)
      end

      # True when the input's host is (or belongs to) a listed URL shortener.
      def shortener?(input)
        !matched_shortener(input).nil?
      end

      # The shortener-list entry that matched the input's host, or nil.
      def matched_shortener(input)
        find_in(shorteners, input)
      end

      # Reduces a URL, bare domain, or email address to a bare lowercase host:
      #   "User@Sub.Example.COM"          -> "sub.example.com"
      #   "HTTPS://example.com:8080/a?b"  -> "example.com"
      #   "a/b@mailinator.com"            -> "mailinator.com"
      #   "example.com."                  -> "example.com"
      # Returns "" when nothing host-like can be extracted. IP literals pass
      # through unchanged (the lists hold domains, so they simply never match).
      #
      # A schemeless input containing @ is treated as an email address FIRST:
      # the local part may legally contain / ? # (RFC 5322 atext), so applying
      # URL delimiters to it would sever the domain ("a/b@mailinator.com" would
      # otherwise read as host "a"). The host is everything after the LAST @.
      #
      # With a scheme:// present it's a URL: the authority is isolated BEFORE
      # any @ handling, so an @ in the path/query/fragment
      # ("/redirect?to=user@mailinator.com") is never mistaken for userinfo,
      # and only the LAST @ within the authority is the userinfo delimiter (per
      # RFC 3986), so "example.com@evil.example" still resolves to
      # "evil.example".
      def extract_host(input)
        candidate = input.to_s.strip.downcase

        if !candidate.match?(%r{\A[a-z][a-z0-9+.-]*://}) && candidate.include?("@")
          return candidate.split("@").last.to_s.sub(/:\d*\z/, "").sub(/\.\z/, "")
        end

        candidate = candidate.sub(%r{\A[a-z][a-z0-9+.-]*://}, "") # scheme
        candidate = candidate.split(%r{[/\\?#]}).first.to_s # authority: cut path/query/fragment
        candidate = candidate.split("@").last.to_s # URL userinfo
        candidate = candidate.sub(/:\d*\z/, "") # port
        candidate.sub(/\.\z/, "") # trailing root dot
      end

      def blocklist
        @blocklist ||= load_set(BLOCKLIST_PATH)
      end

      def shorteners
        @shorteners ||= load_set(SHORTENERS_PATH)
      end

      def blocklist_size
        blocklist.size
      end

      def shortener_size
        shorteners.size
      end

      # Drops the memoized sets so the next check re-reads the data files.
      def reload!
        @blocklist = nil
        @shorteners = nil
      end

      def find_in(set, input)
        host = extract_host(input)
        return nil if host.empty?

        parts = host.split(".")
        (parts.length - 1).downto(0) do |index|
          suffix = parts[index..].join(".")
          return suffix if set.include?(suffix)
        end
        nil
      end

      def load_set(path)
        Set.new(JSON.parse(File.read(path)))
      end
    end
  end
end
