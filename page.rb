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

  def raw_body
    if @rev
       @raw_body ||= ($repo.tree(@rev)/@name).data
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
    $repo.log('master', @name)
  end

  def delta(rev)
    $repo.diff($repo.commit(rev).parents.first, rev, @name)
  end
  
  def previous_commit
    # FIXME this is going through all commits, not just those containing
    # this page
    rev = @rev || $repo.commits.first
    commit = $repo.commit(rev).parents.first
    
    if ($repo.tree(commit.to_s)/@name)
      commit
    else
      nil
    end
  end
  
  def next_commit
    # TODO implement
  end

  def version(rev)
    data = ($repo.tree(rev)/@name).data
    RubyPants.new(RedCloth.new(data).to_html).to_html.wiki_linked
  end
end