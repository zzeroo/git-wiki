require 'rubygems'
require 'extensions'
require 'page'

%w(grit redcloth rubypants uv).each do |gem| 
  require_gem_with_feedback gem
end

GIT_REPO = ARGV[0] || ENV['HOME'] + '/wiki'
GIT_DIR  = File.join(GIT_REPO, '.git')
HOMEPAGE = 'Home'
UV_THEME = 'idle'

unless File.exists?(GIT_DIR) && File.directory?(GIT_DIR)
  FileUtils.mkdir_p(GIT_DIR)
  puts "Initializing repository in #{GIT_REPO}..."
  `/usr/bin/env git --git-dir #{GIT_DIR} init`
end

$repo = Grit::Repo.new(GIT_REPO)