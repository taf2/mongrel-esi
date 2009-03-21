require 'esi'

output = ""

p = ESI::CParser.new

start_tags = []
end_tags = []


p.start_tag_handler do|tag_name, attrs|
  start_tags << {:name => tag_name, :attributes => attrs }
end

p.end_tag_handler do|tag_name|
  end_tags << tag_name
end

p.output_handler do|data|
  output << data
end

p.process "<html><head><body><esi:include timeout='1' max-age='600+600' src=\"hello\"/>some more input"
p.process "some input<esi:include \nsrc='hello'/>some more input\nsome input<esi:include src=\"hello\"/>some more input"
p.process "some input<esi:inline src='hello'/>some more input\nsome input<esi:comment text='hello'/>some more input"
p.process "<p>some input</p><esi:include src='hello'/>some more input\nsome input<esi:include src='hello'/>some more input"
p.process "</body></html>"
p.finish
expected = %Q(<html><head><body>some more inputsome inputsome more input
some inputsome more inputsome inputsome more input
some inputsome more input<p>some input</p>some more input
some inputsome more input</body></html>) 

expected_start_tags = [
  {:name => 'esi:include', :attributes => {"src"=>"hello", "max-age"=>"600+600", "timeout"=>"1"} },
  {:name => 'esi:include', :attributes => {"src"=>"hello", "max-age"=>"600+600", "timeout"=>"1"} },
  {:name => 'esi:include', :attributes => {"src"=>"hello", "max-age"=>"600+600", "timeout"=>"1"} },
  {:name => 'esi:inline',  :attributes => {"src"=>"hello", "max-age"=>"600+600", "timeout"=>"1"} },
  {:name => 'esi:comment', :attributes => {"text"=>"hello", "src"=>"hello", "max-age"=>"600+600", "timeout"=>"1"} },
  {:name => 'esi:include', :attributes => {"text"=>"hello", "src"=>"hello", "max-age"=>"600+600", "timeout"=>"1"} },
  {:name => 'esi:include', :attributes => {"text"=>"hello", "src"=>"hello", "max-age"=>"600+600", "timeout"=>"1"} }
]
expected_end_tags =[ 'esi:include', 'esi:include', 'esi:include', 'esi:inline', 'esi:comment', 'esi:include', 'esi:include']

if( start_tags.size != expected_start_tags.size and end_tags.size != expected_end_tags.size )
  puts "Failed expected start tags: #{expected_start_tags.size}, expected end tags: #{expected_end_tags.size}"
  puts "Actual: start tags: #{start_tags.size}, end tags: #{end_tags.size}"
  exit(1)
end

if expected_start_tags != start_tags
  puts "Failed expected start tags: #{expected_start_tags.inspect}"
  puts "Actual start tags: #{start_tags.inspect}"
  exit(1)
end

if expected_end_tags != end_tags
  puts "Failed expected end tags: #{expected_end_tags.inspect}"
  puts "Actual end tags: #{end_tags.inspect}"
  exit(1)
end

if( expected != output )
  puts "Failed output was different from the expected"
  puts "Expected: #{expected}"
  puts "\n"
  puts "Actual: #{output}"
  exit(1)
end

p.esi_tag = "hello"

if( "hello" != p.esi_tag )
  puts "Failed esi_tag could not be set"
  exit(1)
end

p.depth = 1
if( 1 != p.depth )
  puts "Failed depth could not be set"
  exit(1)
end

puts "PASSED"

p = nil

GC.start
