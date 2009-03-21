# much of this file orginated as part of mongrel
require 'rake'
require 'rake/testtask'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'tools/rakehelp'
require 'fileutils'
include FileUtils

setup_tests

setup_clean ["ext/esi/*.{bundle,so,obj,pdb,lib,def,exp}", "ext/esi/Makefile", "pkg", "lib/*.bundle", "*.gem", "doc/site/output", ".config"]

setup_rdoc ['README', 'LICENSE', 'COPYING', 'lib/**/*.rb', 'doc/**/*.rdoc', 'ext/**/*.{h,c,rl}']

desc "Does a full compile, test run"
task :default => [:compile, :test]

desc "Compiles all extensions"
task :compile => [:esi] do
  if Dir.glob(File.join("lib","esi.*")).length == 0
    STDERR.puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    STDERR.puts "Gem actually failed to build.  Your system is"
    STDERR.puts "NOT configured properly to build MongrelESI."
    STDERR.puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit(1)
  end
end

setup_extension("esi", "esi")

task :package => [:clean,:compile,:test,:rerdoc]


namespace :ragel do
  def ragel_version
    `ragel --version`.scan(/version ([0-9\.]+)/).first.first
  end
  desc 'test the ragel version'
  task :verify do
    if ragel_version < "5.24"
      puts "You need to install a version of ragel greater or equal to 5.24"
      exit(1)
    else
      puts "Using ragel #{ragel_version}"
    end
  end

  desc 'generate the ruby ragel parser'
  task :ruby => :verify do
    Dir.chdir "ext/esi" do
      sh "ragel -R ruby_esi.rl | rlgen-ruby -o machine.rb"
      raise "Failed to build Ruby source" unless File.exist? "machine.rb"
    end
  end
  
  desc 'generate the ragel parser'
  task :gen => :verify do
    Dir.chdir "ext/esi" do
      if ragel_version < "6.0"
        sh "ragel parser.rl | rlgen-cd -G1 -o parser.c"
      else
        sh "ragel -s parser.rl -G1 -o parser.c"
      end
      raise "Failed to build ESI parser source" unless File.exist? "parser.c"
    end
  end
  
  desc 'generate the ruby ragel parser'
  task :ruby => :verify do
    Dir.chdir "ext/esi" do
      sh "ragel -R ruby_esi.rl | rlgen-ruby -o machine.rb"
      raise "Failed to build Ruby source" unless File.exist? "machine.rb"
    end
  end

  desc 'generate a PNG graph of the parser'
  task :graph => :verify do
    Dir.chdir "ext/esi" do
      if ragel_version < "6.0"
        sh 'ragel parser.rl | rlgen-dot -p > esi.dot'
      else
        sh 'ragel -V parser.rl -p > esi.dot'
      end
      sh 'dot -Tpng esi.dot -o ../../esi.png'
      #sh 'dot -Tgif esi.dot -o ../../esi.gif'
    end
  end
end

namespace :size do
  desc 'Number of lines of code and tests'
  task :measure => [:tests,:code]

  desc 'Number of lines of tests'
  task :tests do
    sh 'find test/ -name "*.rb" | xargs wc -l'
  end

  desc 'Number of lines of code'
  task :code do 
    sh 'find lib/ ext/ -name "*.r*" | grep -v svn | xargs wc -l'
  end
end

name='mongrel_esi'
require File.join(File.dirname(__FILE__),'lib','esi','version')

setup_gem(name, ESI::VERSION::STRING) do |spec|
  spec.summary = "A small fast ESI HTTP Server built on top of Mongrel"
  spec.description = spec.summary
  spec.test_files = Dir.glob('test/test_*.rb')
  spec.author="Todd A. Fisher"
  spec.email="todd.fisher@gmail.com"
  spec.homepage="http://code.google.com/p/mongrel-esi"
  spec.rubyforge_project = "mongrel-esi"
  spec.executables=['mongrel_esi']
  spec.files += %w(COPYING LICENSE README Rakefile setup.rb)

  spec.required_ruby_version = '>= 1.8.5'

	if RUBY_PLATFORM =~ /mswin/
    spec.platform = Gem::Platform::CURRENT
  else
    spec.add_dependency('daemons', '>= 1.0.3') # XXX: verify we are using this correctly
    spec.add_dependency('fastthread', '>= 0.6.2') # mongrel needs it so do we
  end

  spec.add_dependency('hpricot', '>= 0.6') # used for invalidation protocol parsing
  spec.add_dependency('memcache-client', '>= 1.5.0')
  spec.add_dependency('cgi_multipart_eof_fix', '>= 1.0.0') # mongrel needs it so do we
  spec.add_dependency('mongrel', '>= 1.0.1') # we need mongrel
end

task :install do
  sh %{rake package}
  sh %{gem install pkg/#{name}-#{ESI::VERSION::STRING}}
end

task :uninstall => [:clean] do
  sh %{gem uninstall #{name}}
end

task :website => [:rcov, :rdoc] do
  #sh %{ rsync -avz --rsh=ssh pkg/#{name-#{ESI::VERSION::STRING}
  sh %{ scp -r doc/rdoc doc/index.html Changelog test/coverage mongrel-esi.rubyforge.org:/var/www/gforge-projects/mongrel-esi/ }
end
