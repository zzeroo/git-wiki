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
  
  def branch_name
    $repo.current_branch
  end
  
  def updated_at
    commit.committer_date rescue Time.now
  end

  def raw_body
    if @rev
       @raw_body ||= blob.contents
    else
      @raw_body ||= File.exists?(@filename) ? File.read(@filename) : ''
    end
  end

  def update(content, message=nil)
    File.open(@filename, 'w') { |f| f << content }
    commit_message = tracked? ? "edited #{@name}" : "created #{@name}" 
    commit_message += ' : ' + message if message && message.length > 0
    begin
      $repo.add(@name)
      $repo.commit(commit_message)
    rescue 
      nil
    end
  end

  def tracked?
    begin
      $repo.gtree('HEAD').children.keys.include?(@name)
    rescue 
      false
    end
  end

  def history
    return nil unless tracked?
    @history ||= $repo.log.path(@name)
  end

  def delta(rev)
    $repo.diff(previous_commit, rev).path(@name).patch
  end
  
  def commit
    @commit ||= $repo.log.object(@rev || 'master').path(@name).first
  end

  def previous_commit
    @previous_commit ||= $repo.log(2).object(@rev || 'master').path(@name).to_a[1]
  end

  def next_commit
    begin
      if (self.history.first.sha == self.commit.sha)
        @next_commit ||= nil
      else
        matching_index = nil
        history.each_with_index { |c, i| matching_index = i if c.sha == self.commit.sha }
        @next_commit ||= history.to_a[matching_index - 1]
      end
    rescue 
      @next_commit ||= nil
    end
  end

  def version(rev)
    data = blob.contents
    RubyPants.new(RedCloth.new(data).to_html).to_html.wiki_linked
  end

  def blob
    @blob ||= ($repo.gblob(@rev + ':' + @name))
  end
end