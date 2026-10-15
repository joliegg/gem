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

      # Reduces a URL, bare domain, or email address to its primary host:
      #   "User@Sub.Example.COM"          -> "sub.example.com"
      #   "HTTPS://example.com:8080/a?b"  -> "example.com"
      #   "a/b@mailinator.com"            -> "mailinator.com"
      #   "example.com."                  -> "example.com"
      # Returns "" when nothing host-like can be extracted. This is the FIRST
      # candidate host; matching uses candidate_hosts, which can hold both
      # readings of an ambiguous input.
      def extract_host(input)
        candidate_hosts(input).first.to_s
      end

      # Every host an input may resolve to, deduplicated, most likely reading
      # first. Whitespace is stripped EVERYWHERE (not just the ends), matching
      # the normalization URL validators and crawlers apply before resolving —
      # "https://mai linator.com" resolves to mailinator.com for them, so it
      # must match here too.
      #
      # - With a scheme:// the URL authority only: an @ later in the URL is
      #   path/query content, not userinfo, and only the LAST @ within the
      #   authority is the userinfo delimiter (RFC 3986), so
      #   "example.com@evil.example" resolves to "evil.example".
      # - Schemeless with an @ is ambiguous: an email whose local part may
      #   legally contain / ? # (RFC 5322 atext — "a/b@mailinator.com"), or a
      #   bare URL carrying an @ ("mailinator.com/path@allowed.example", whose
      #   crawled host is mailinator.com). Both readings are returned so
      #   neither interpretation slips a listed host past the guard.
      # - Otherwise the bare host itself.
      def candidate_hosts(input)
        candidate = input.to_s.downcase.gsub(/\s+/, "")
        return [] if candidate.empty?

        hosts =
          if candidate.match?(%r{\A[a-z][a-z0-9+.-]*://})
            [authority_host(candidate)]
          elsif candidate.include?("@")
            [candidate.split("@").last.to_s, authority_host(candidate)]
          else
            [authority_host(candidate)]
          end

        hosts.map { |host| normalize_host(host) }.reject(&:empty?).uniq
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

      # The candidate host that produced a blocklist match, or nil — e.g.
      # "sub.mailinator.com" for a match on entry "mailinator.com".
      def matched_host(input)
        match_in(blocklist, input)&.last
      end

      def find_in(set, input)
        match_in(set, input)&.first
      end

      def match_in(set, input)
        candidate_hosts(input).each do |host|
          parts = host.split(".")
          (parts.length - 1).downto(0) do |index|
            suffix = parts[index..].join(".")
            return [suffix, host] if set.include?(suffix)
          end
        end
        nil
      end

      # The host out of a URL authority: strips any scheme, cuts path/query/
      # fragment, and keeps only what follows the LAST @ (userinfo delimiter).
      def authority_host(candidate)
        candidate
          .sub(%r{\A[a-z][a-z0-9+.-]*://}, "")
          .split(%r{[/\\?#]}).first.to_s
          .split("@").last.to_s
      end

      def normalize_host(host)
        host.sub(/:\d*\z/, "").sub(/\.\z/, "")
      end

      def load_set(path)
        Set.new(JSON.parse(File.read(path)))
      end
    end
  end
end
