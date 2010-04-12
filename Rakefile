require 'rubygems'
require 'rake'

begin

  require 'jeweler'

  Jeweler::Tasks.new do |gem|

    gem.name        = "data_table"
    gem.summary     = %Q{Smart export of arbitrary ruby object collections}
    gem.description = %Q{Smart export of arbitrary ruby object collections}
    gem.email       = "ma@zive.at"
    gem.homepage    = "http://github.com/michael/data_table"
    gem.authors     = ["Michael Aufreiter"]

    gem.add_development_dependency 'shoulda',   '~> 2.10.3'

  end

  Jeweler::GemcutterTasks.new

rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test
