#!/usr/bin/env ruby

%w(rubygems sinatra grit redcloth rubypants uv).each do |a_gem| 
  begin
    require a_gem
  rescue LoadError => e
    puts "You need to 'sudo gem install #{a_gem}' before we can proceed"
  end
end

GIT_REPO = ARGV[1] || ENV['HOME'] + '/wiki'
GIT_DIR  = File.join(GIT_REPO, '.git')
HOMEPAGE = 'Home'
UV_THEME = 'twilight'

unless File.exists?(GIT_DIR) && File.directory?(GIT_DIR)
  FileUtils.mkdir_p(GIT_DIR)
  puts "Initializing repository in #{GIT_REPO}..."
  `git --git-dir #{GIT_DIR} init`
end

$repo = Grit::Repo.new(GIT_REPO)

class String
  def wiki_linked
    self.gsub!(/\b((?:[A-Z]\w+){2,})/) { |m| "<a href=\"/e/#{m}\">#{m}</a>" }
  end
end

class Page
  attr_reader :name

  def initialize(name)
    @name = name
    @filename = File.join(GIT_REPO, @name)
  end

  def body
    @body ||= RedCloth.new(RubyPants.new(raw_body).to_html).to_html.wiki_linked
  end

  def raw_body
    @raw_body ||= File.exists?(@filename) ? File.read(@filename) : ''
  end

  def body=(content)
    File.open(@filename, 'w') { |f| f << content }
    message = tracked? ? "Edited #{@name}" : "Created #{@name}"
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
    ($repo.tree(rev)/@name).data
  end

  def to_s
    "<li><strong><a href='/#{@name}'>#{@name}</a></strong> — <a href='/e/#{@name}'>edit</a></li>"
  end
end

get('/') { redirect '/' + HOMEPAGE }
get('/_stylesheet.css') { File.read(File.join(File.dirname(__FILE__), 'stylesheet.css')) }
get('/_code.css') { File.read(File.join(File.dirname(__FILE__), 'css', "#{UV_THEME}.css")) }

get '/_list' do
  if $repo.commits.empty?
    @pages = []
  else
    @pages = $repo.commits.first.tree.contents.map { |blob| Page.new(blob.name) }
  end
  
  list
end

get '/:page' do
  @page = Page.new(params[:page])
  @page.tracked? ? show : redirect('/e/' + @page.name)
end

get '/e/:page' do
  @page = Page.new(params[:page])
  edit
end

post '/e/:page' do
  @page = Page.new(params[:page])
  @page.body = params[:body]
  redirect '/' + @page.name
end

get '/h/:page' do
  @page = Page.new(params[:page])
  history
end

get '/h/:page/:rev' do
  @page = Page.new(params[:page])
  version
end

get '/d/:page/:rev' do
  @page = Page.new(params[:page])
  delta
end

def layout(title, content)
  <<-HTML
  <html>
    <head>
      <title>#{title}</title>
      <link rel="stylesheet" href="/_stylesheet.css" type="text/css" media="screen" />
      <link rel="stylesheet" href="/_code.css" type="text/css" media="screen" />
      <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    </head>
    <body>
      <div id="navigation">
        <a href="/">Home</a>
        <a href="/_list">List</a>
      </div>
      #{content}
    </body>
  </html>
  HTML
end

def show
  layout(@page.name,
  <<-HTML
  <a href="/e/#{@page.name}" class="edit_link">edit this page</a>
  <a href="/h/#{@page.name}" class="edit_link">history of this page</a>
  <h1 class="page_title">#{@page.name}</h1>
  <div id="page_content">#{@page.body}</div>  
  HTML
  )
end

def version
  layout(@page.name, 
  <<-HTML
  <a href="/e/#{@page.name}" class="edit_link">edit this page</a>
  <a href="/h/#{@page.name}" class="edit_link">history of page</a>
  <h1 class="page_title">#{@page.name}</h1>
  <div id="page_content">#{@page.version(params[:rev])}</div>
  HTML
  )
end

def edit
  layout("Editing #{@page.name}",
  <<-HTML
  <h1>Editing #{@page.name}</h1>
  <a href="javascript:history.back();" class="cancel">Cancel</a>
  <form method="post" action="/e/#{params[:page]}">
    <p>
      <textarea name="body" rows="25" cols="130">
        #{@page.raw_body}
      </textarea>
    </p>
    <p><input type="submit" value="Save as the newest version" class="submit" /></p>
  </form>
  HTML
  )
end

def delta  
  diff = @page.delta(params[:rev])
  highlighted_diff = Uv.parse(diff, "xhtml", "diff", true, UV_THEME)
  
  layout("Diff of #{@page.name}", 
  <<-HTML
  <h1>Diff of <a href="/#{@page.name}">#{@page.name}</a></h1>
  #{highlighted_diff}
  HTML
  )
end

def history
  commits = ""
  @page.history.each do |c| 
    commits += "<li><em>#{c.committed_date}</em> "
    commits += "<a href=\"/h/#{@page.name}/#{c.id}\">#{c.message}</a> "
    commits += "<a href=\"/d/#{@page.name}/#{c.id}\">diff</a>" unless c.parents.empty?
    commits += "</li>"
  end
  
  layout("History of #{@page.name}",
  <<-HTML
  <h1>History of <a href="/#{@page.name}">#{@page.name}</a></h1>
  <ul>#{commits}</ul>
  HTML
  )
end

def list
  if @pages.empty?
    layout('Listing pages', '<p>No pages found.</p>')
  else
    layout('Listing pages',   
    <<-HTML
    <h1>All pages</h1>
    <ul>#{@pages.each {|page| page.to_s}}</ul>
    HTML
    )
  end
end
