require 'uv'

class Page
  attr_reader :name

  def initialize(name, rev=nil)
    @name = name
    @rev = rev
    @filename = File.join(GIT_REPO, @name)
  end

  def body
    ext = File.extname(@filename)
    unless ext.empty?
      @body ||= Uv.parse(raw_body, "xhtml", Uv.syntax_for_file_extension(ext), false, UV_THEME)
    else
      @body ||= RubyPants.new(RedCloth.new(raw_body).to_html).to_html.wiki_linked
    end
  end

  def updated_at
    commit.committed_date
  end

  def raw_body
    if @rev
       @raw_body ||= blob.data
    else
      @raw_body ||= File.exists?(@filename) ? File.read(@filename) : ''
    end
  end

  def body=(content)
    File.open(@filename, 'w') { |f| f << content }
    message = tracked? ? "edited #{@name}" : "created #{@name}"
    `cd #{GIT_REPO} && git add #{@name} && git commit -m "#{message}"`
  end

  def tracked?
    return false if $repo.commits.empty?
    $repo.commits.first.tree.contents.map { |b| b.name }.include?(@name)
  end

  def history
    return nil unless tracked?
    @history ||= $repo.log('master', @name)
  end

  def delta(rev)
    $repo.diff(previous_commit, rev, @name)
  end
  
  def commit
    @commit ||= $repo.log(@rev || 'master', @name, {"max-count" => 1}).first
  end

  def previous_commit
    @previous_commit ||= $repo.log(@rev || 'master', @name, {"max-count" => 2})[1]
  end

  def next_commit
    if self.history[0].to_s == self.commit.to_s
      @next_commit ||= nil
    else
      matching_index = nil
      history.each_with_index { |c, i| matching_index = i if c.to_s == self.commit.to_s }
      @next_commit ||= history[matching_index - 1]
    end
  end

  def version(rev)
    data = blob.data
    RubyPants.new(RedCloth.new(data).to_html).to_html.wiki_linked
  end

  def blob
    @blob ||= ($repo.tree(@rev)/@name)
  end
end