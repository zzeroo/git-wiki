#!/usr/bin/env ruby

require 'environment'

require_gem_with_feedback 'sinatra'

layout { File.read('views/layout.erb') }

def show(template, title)
  @title = title
  erb(template)
end

def page_with_ext
  if params[:format] == "html"
    params[:page]
  else
    "#{params[:page]}.#{params[:format]}"
  end
end

def page_url
  "#{request.env["rack.url_scheme"]}://#{request.env["HTTP_HOST"]}#{request.env["REQUEST_PATH"]}"
end

get('/') { redirect '/' + HOMEPAGE }
get('/_style.css') { header 'Content-Type' => 'text/css'; File.read(File.join(File.dirname(__FILE__), 'css', 'style.css')) }
get('/_code.css') { header 'Content-Type' => 'text/css'; File.read(File.join(File.dirname(__FILE__), 'css', "#{UV_THEME}.css")) }
get('/_app.js') { header 'Content-Type' => 'application/x-javascript'; File.read(File.join(File.dirname(__FILE__), 'javascripts', "application.js")) }

get '/_list' do
  if $repo.commits.empty?
    @pages = []
  else
    @pages = $repo.commits.first.tree.contents.map { |blob| Page.new(blob.name) }
  end

  show(:list, 'Listing pages')  
end

get '/:page' do
  @page_url = page_url
  @page = Page.new(page_with_ext)
  @page.tracked? ? show(:show, @page.name) : redirect('/e/' + @page.name)
end

get '/:page/append' do
  @page = Page.new(page_with_ext)
  @page.body = @page.raw_body + "\n\n" + params[:text]
  redirect '/' + @page.name
end

get '/e/:page' do
  @page = Page.new(page_with_ext)
  show :edit, "Editing #{@page.name}"
end

post '/e/:page' do
  @page = Page.new(page_with_ext)
  @page.body = params[:body]
  redirect '/' + @page.name
end

get '/h/:page' do
  @page = Page.new(page_with_ext)
  show :history, "History of #{@page.name}"
end

['/h/:page/:rev', '/h/:page.:format/:rev'].each do |r|
  get r do
    @page = Page.new(page_with_ext, params[:rev])
    show :show, "#{@page.name} (version #{params[:rev]})"
  end
end

['/d/:page/:rev', '/d/:page.:format/:rev'].each do |r|
  get r do
    @page = Page.new(page_with_ext)
    show :delta, "Diff of #{@page.name}"
  end
end
