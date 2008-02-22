class Page
  attr_reader :name

  def initialize(name)
    @name = name
    @filename = File.join(GIT_REPO, @name)
  end

  def body
    @body ||= RubyPants.new(RedCloth.new(raw_body).to_html).to_html.wiki_linked
  end

  def raw_body
    @raw_body ||= File.exists?(@filename) ? File.read(@filename) : ''
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

  def version(rev)
    data = ($repo.tree(rev)/@name).data
    RubyPants.new(RedCloth.new(data).to_html).to_html.wiki_linked
  end
end