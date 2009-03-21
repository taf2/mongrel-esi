require 'esi'

10.times do
  output = ""
  # TODO: support passing output stream to new
  p = ESI::CParser.new

  # TODO: support attributes
  p.start_tag_handler do|tag_name, attrs|
    puts "Start: #{tag_name} #{attrs.inspect}"
  end

  p.end_tag_handler do|tag_name|
    puts "End: #{tag_name}"
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

  if( expected !=  output )
    puts "Failed output was different from the expected"
    puts "Expected: #{expected}"
    puts "\n"
    puts "Actual: #{output}"
    exit(1)
  end
end

puts "PASSED"

#p = nil

GC.start
