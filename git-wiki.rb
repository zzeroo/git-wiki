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
    self
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

layout { File.read('views/layout.erb') }

def show(template, title)
  @title = title
  erb template
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

  show(:list, 'Listing pages')  
end

get '/:page' do
  @page = Page.new(params[:page])
  @page.tracked? ? show(:show, @page.name) : redirect('/e/' + @page.name)
end

get '/e/:page' do
  @page = Page.new(params[:page])
  show :edit, "Editing #{@page.name}"
end

post '/e/:page' do
  @page = Page.new(params[:page])
  @page.body = params[:body]
  redirect '/' + @page.name
end

get '/h/:page' do
  @page = Page.new(params[:page])
  show :history, "History of #{@page.name}"
end

get '/h/:page/:rev' do
  @page = Page.new(params[:page])
  show :version, "Version of #{@page.name}"
end

get '/d/:page/:rev' do
  @page = Page.new(params[:page])
  show :delta, "Diff of #{@page.name}"
end
