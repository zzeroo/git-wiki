class Page
  attr_reader :name

  def initialize(name, rev=nil)
    @name = name
    @rev = rev
    @filename = File.join(GIT_REPO, @name)
  end

  def body
    @body ||= RubyPants.new(RedCloth.new(raw_body).to_html).to_html.wiki_linked
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

  def previous_commit
    @previous_commit ||= $repo.log(@rev || 'master', @name, {"max-count" => 2})[1]
  end

  def next_commit
    # TODO implement - use history & commit
  end

  def version(rev)
    data = blob.data
    RubyPants.new(RedCloth.new(data).to_html).to_html.wiki_linked
  end

  def commit
    @commit ||= $repo.log(@rev || 'master', @name, {"max-count" => 1}).first
  end

  def blob
    @blob ||= ($repo.tree(@rev)/@name)
  end
end