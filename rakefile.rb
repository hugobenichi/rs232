task :test_global do ruby "test/test_rs232.rb" end
task :test_local  do ruby "-Ilib test/test_rs232.rb" end

task :gem_build   do sh "gem build rs232.gemspec" end
task :gem_install => :gem_build do 
  gemfile = Dir.new("./").entries.select{ |f| f =~ /rs232-[\d]+\.[\d]+\.[\d]+.gem/ }.sort[-1]
  puts "installing %s" % gemfile
  sh "gem install --local %s" % gemfile
end

task :default => :test_local