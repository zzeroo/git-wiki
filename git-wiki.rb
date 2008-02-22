#!/usr/bin/env ruby

%w(rubygems sinatra grit redcloth rubypants uv).each do |a_gem| 
  begin
    require a_gem
  rescue LoadError => e
    puts "You need to 'sudo gem install #{a_gem}' before we can proceed"
  end
end

require 'page'
require 'extensions'

GIT_REPO = ARGV[1] || ENV['HOME'] + '/wiki'
GIT_DIR  = File.join(GIT_REPO, '.git')
HOMEPAGE = 'Home'
UV_THEME = 'idle'

unless File.exists?(GIT_DIR) && File.directory?(GIT_DIR)
  FileUtils.mkdir_p(GIT_DIR)
  puts "Initializing repository in #{GIT_REPO}..."
  `git --git-dir #{GIT_DIR} init`
end

$repo = Grit::Repo.new(GIT_REPO)

layout { File.read('views/layout.erb') }

def show(template, title)
  @title = title
  erb(template)
end

get('/') { redirect '/' + HOMEPAGE }
get('/_style.css') { File.read(File.join(File.dirname(__FILE__), 'css', 'style.css')) }
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
