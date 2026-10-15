# frozen_string_literal: true

module Jolie
  module Moderation
    # One detected moderation category, mirroring the TS package's
    # { category, confidence } entries, plus the list entry that matched when
    # the source is one of the bundled lists (nil for API-backed categories).
    Category = Struct.new(:category, :confidence, :matched)

    # The outcome of moderating one input, mirroring the TS package's
    # ModerationResult: the original source plus every category detected on it.
    Result = Struct.new(:source, :moderation) do
      def flagged?
        moderation.any?
      end

      def categories
        moderation.map(&:category)
      end
    end
  end
end
