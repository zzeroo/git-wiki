require 'rubygems'
require 'extensions'
require 'page'

%w(git redcloth rubypants).each do |gem| 
  require_gem_with_feedback gem
end

GIT_REPO = ARGV[0] || ENV['HOME'] + '/wiki'
HOMEPAGE = 'home'

unless File.exists?(GIT_REPO) && File.directory?(GIT_REPO)
  puts "Initializing repository in #{GIT_REPO}..."
  Git.init(GIT_REPO)
end

$repo = Git.open(GIT_REPO)