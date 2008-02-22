class String
  def wiki_linked
    self.gsub!(/\b((?:[A-Z]\w+){2,})/) { |m| "<a href=\"/e/#{m}\">#{m}</a>" }
    self
  end
end