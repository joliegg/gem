# frozen_string_literal: true

require_relative "moderation/result"
require_relative "moderation/url_blocklist"

module Jolie
  # Ruby counterpart of the @joliegg/moderation TypeScript package. The URL
  # blocklist is the first capability ported; text/image/audio moderation can
  # follow under this same namespace.
  module Moderation
    module_function

    # Checks a link against the bundled lists, mirroring the TS
    # ModerationClient#moderateLink list checks (without the Google WebRisk
    # lookup). Returns a Result whose moderation categories are "BLACK_LIST"
    # for a blocklisted host and "URL_SHORTENER" for a shortener host; a
    # shortener is only reported when allow_shorteners is false, and a
    # blocklisted host is reported even when it is also a shortener.
    def moderate_link(url, allow_shorteners: false)
      moderation = []

      if (matched = UrlBlocklist.match(url))
        moderation << Category.new(category: "BLACK_LIST", confidence: 100, matched: matched)
      elsif !allow_shorteners && (matched = UrlBlocklist.matched_shortener(url))
        moderation << Category.new(category: "URL_SHORTENER", confidence: 100, matched: matched)
      end

      Result.new(source: url, moderation: moderation)
    end

    # True when moderate_link flags the link for any category.
    def link_blocked?(url, allow_shorteners: false)
      moderate_link(url, allow_shorteners: allow_shorteners).flagged?
    end
  end
end
