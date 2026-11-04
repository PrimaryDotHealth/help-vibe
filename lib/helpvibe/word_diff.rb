require "diff/lcs"

module Helpvibe
  # Word-level diff of two plain texts, for revision history (S13).
  # Returns [[:same|:ins|:del, "text"], ...] with runs merged.
  module WordDiff
    def self.call(old_text, new_text)
      a = old_text.to_s.split(/(\s+)/)
      b = new_text.to_s.split(/(\s+)/)
      runs = []
      Diff::LCS.sdiff(a, b).each do |c|
        case c.action
        when "=" then push(runs, :same, c.old_element)
        when "-" then push(runs, :del, c.old_element)
        when "+" then push(runs, :ins, c.new_element)
        when "!" then push(runs, :del, c.old_element); push(runs, :ins, c.new_element)
        end
      end
      runs
    end

    def self.stats(runs)
      { added: runs.count { _1[0] == :ins && _1[1].strip.present? }, removed: runs.count { _1[0] == :del && _1[1].strip.present? } }
    end

    def self.push(runs, kind, text)
      return if text.nil?
      if runs.last&.first == kind then runs.last[1] << text else runs << [ kind, +text ] end
    end
  end
end
