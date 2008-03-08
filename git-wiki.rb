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

def touchfile
  # adds meta file to repo so we have somthing to commit initially
  $repo.chdir do
    f = File.new(".meta",  "w+")
    f.puts($repo.current_branch)
    f.close
    $repo.add('.meta')
  end
end

get('/') { redirect '/' + HOMEPAGE }
get('/_style.css') { header 'Content-Type' => 'text/css'; File.read(File.join(File.dirname(__FILE__), 'css', 'style.css')) }
get('/_code.css') { header 'Content-Type' => 'text/css'; File.read(File.join(File.dirname(__FILE__), 'css', "#{UV_THEME}.css")) }
get('/_app.js') { header 'Content-Type' => 'application/x-javascript'; File.read(File.join(File.dirname(__FILE__), 'javascripts', "application.js")) }

get '/_list' do
  @pages = $repo.log.first.gtree.children.map { |name, blob| Page.new(name) } rescue []
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
  @page.update(params[:body], params[:message])
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

get '/a/tarball' do
  header 'Content-Type' => 'application/x-gzip'
  header 'Content-Disposition' => 'filename=archive.tgz'
  archive = $repo.archive('HEAD', nil, :format => 'tgz', :prefix => 'wiki/')
  File.open(archive).read
end

get '/a/branches' do
  @branches = $repo.branches
  show :branches, "Branches List"
end

get '/a/branch/:branch' do
  $repo.checkout(params[:branch])
  redirect '/' + HOMEPAGE
end

get '/a/history' do
  @history = $repo.log
  show :branch_history, "Branch History"
end

get '/a/revert_branch/:sha' do
  $repo.with_temp_index do 
    $repo.read_tree params[:sha]
    $repo.checkout_index
    $repo.commit('reverted branch')
  end
  redirect '/a/history'
end

get '/a/merge_branch/:branch' do
  $repo.merge(params[:branch])
  redirect '/' + HOMEPAGE
end

get '/a/delete_branch/:branch' do
  $repo.branch(params[:branch]).delete
  redirect '/a/branches'
end

post '/a/new_branch' do
  $repo.branch(params[:branch]).create
  $repo.checkout(params[:branch])
  if params[:type] == 'blank'
    # clear out the branch
    $repo.chdir do 
      Dir.glob("*").each do |f|
        File.unlink(f)
        $repo.remove(f)
      end
      touchfile
      $repo.commit('clean branch start')
    end
  end
  redirect '/a/branches'
end
