# This final came directly from mongrel 1.0.1 source
# with a few modifications to support some of my network tests
# Also, i have figured out yet if this should remain so much a clone of the mongrel tree
# or become a plugin, need to review more closely how that works

def make(makedir)
  Dir.chdir(makedir) do
    sh(Gem::Platform::RUBY =~ /win32/ ? 'nmake' : 'make')
  end
end

def extconf(dir)
  Dir.chdir(dir) do ruby "extconf.rb" end
end

def setup_tests
  Rake::TestTask.new do |t|
    t.test_files = FileList["test/unit/*_test.rb"] + FileList["test/integration/*_test.rb"]
    t.verbose = true
  end

  Rake::TestTask.new("test:net") do |t|
    t.libs << "test/net"
    t.test_files = FileList['test/net/*_test.rb']
    t.verbose = true
  end
end


def setup_clean otherfiles
  files = ['build/*', '**/*.o', '**/*.so', '**/*.a', 'lib/*-*', '**/*.log'] + otherfiles
  CLEAN.include(files)
end


def setup_rdoc files
  Rake::RDocTask.new do |rdoc|
    rdoc.rdoc_dir = 'doc/rdoc'
    rdoc.options << '--line-numbers'
    rdoc.rdoc_files.add(files)
  end
end


def setup_extension(dir, extension)
  ext = "ext/#{dir}"
  ext_so = "#{ext}/#{extension}.#{Config::CONFIG['DLEXT']}"
  ext_files = FileList[
    "#{ext}/*.c",
    "#{ext}/*.h",
    "#{ext}/extconf.rb",
    "#{ext}/Makefile",
    "lib"
  ]

  task "lib" do
    directory "lib"
  end

  desc "Builds just the #{extension} extension"
  task extension.to_sym => ["#{ext}/Makefile", ext_so ]

  file "#{ext}/Makefile" => ["#{ext}/extconf.rb"] do
    extconf "#{ext}"
  end

  file ext_so => ext_files do
    make "#{ext}"
    cp ext_so, "lib"
  end
end


def base_gem_spec(pkg_name, pkg_version)
  rm_rf "test/coverage"
  pkg_version = pkg_version
  pkg_name    = pkg_name
  pkg_file_name = "#{pkg_name}-#{pkg_version}"
  Gem::Specification.new do |s|
    s.name = pkg_name
    s.version = pkg_version
    s.platform = Gem::Platform::RUBY
    s.has_rdoc = true
    s.extra_rdoc_files = [ "README" ]

    s.files = %w(COPYING LICENSE README Rakefile) +
      Dir.glob("{bin,doc/rdoc,test}/**/*") + 
      Dir.glob("ext/**/*.{h,c,rb,rl}") +
      Dir.glob("{examples,tools,lib}/**/*.rb")

    s.require_path = "lib"
    s.extensions = FileList["ext/**/extconf.rb"].to_a
    s.bindir = "bin"
  end
end

def setup_gem(pkg_name, pkg_version)
  spec = base_gem_spec(pkg_name, pkg_version)
  yield spec if block_given?

  Rake::GemPackageTask.new(spec) do |p|
    p.gem_spec = spec
    p.need_tar = true if RUBY_PLATFORM !~ /mswin/
  end
end

# Conditional require rcov/rcovtask if present
begin
  require 'rcov/rcovtask'
  
  Rcov::RcovTask.new do |t|
    t.test_files = FileList['test/unit/*_test.rb'] + FileList["test/integration/*_test.rb"]
    t.rcov_opts << "-x /usr -x /Library"
    t.output_dir = "test/coverage"
		t.verbose = true
  end
rescue Object => e
	puts e.message
end
