require File.join(File.dirname(__FILE__),'help.rb')
require 'esi/response'

$run_sample_once = false
class ParseOutputTest < Test::Unit::TestCase
  include TestServer
  
  def setup_extra
    @sample_file =  File.join(File.dirname(__FILE__),'esi-sample.html')
    if !$run_sample_once   
      File.open('out-sample.html','w') do|output|
        @cache = ESI::RubyCache.new
        @parser = ESI::CParser.new
        @parser.output = output

        @parser.start_tag_handler do|tag_name,attrs|
          tag = ESI::Tag::Base.create(@test_router, {}, {}, tag_name.gsub(/esi:/,''), attrs, @cache)
          if @parser.esi_tag
            @parser.esi_tag.add_child(tag)
          else
            @parser.esi_tag = tag
          end
        end

        @parser.end_tag_handler do|tag_name|
          #puts "match: '#{@parser.esi_tag.name}' with '#{tag_name.gsub(/esi:/,'')}'"
          if @parser.esi_tag.name == tag_name.gsub(/esi:/,'')
            begin
              @parser.esi_tag.close(@parser.output)
            rescue Object => e
              puts @parser.esi_tag.name
              puts e.message, e.backtrace.join("\n")
            end
            @parser.esi_tag = nil
          else
            @parser.esi_tag.close_child(@parser.output,tag_name)
          end
        end

        File.open( @sample_file,'r') do|input|
          while( (buf=input.read(128)) and !input.eof? and buf.size != 0 )
            @parser.process buf
          end
          @parser.process buf
        end
        @parser.finish
      end

      $run_sample_once = true
    end
    @output=File.read('out-sample.html')
  end

  def test_ouput_body
    assert_match(/  <div class="body">/, @output)
  end
  def test_ouput_some_content
    assert_match(/    <div>some content<\/div>/, @output)
  end
  def test_output_comments
    assert_match(/    <!-- a little commentary -->/, @output)
    assert_match(%q(<!-- a 
      multiline comment -->),@output)
  end
  def test_output_cdata
    assert_match(%q(<![CDATA[
      Some cdata fun fun fun
    ]]>), @output)
  end
  def test_output_doctype
    assert_match(/<!DOCTYPE html PUBLIC "-\/\/W3C\/\/DTD XHTML 1.0 Strict\/\/EN" "http:\/\/www.w3.org\/TR\/xhtml1\/DTD\/xhtml1-strict.dtd">/, @output)
  end
  def test_output_complete
    assert_match(/<\/html>/, @output)
  end
  def test_output_no_esi_tags
    assert_no_match(/<esi:/, @output)
  end

  def test_includes_appeared
    assert_match(/<div id='1'>id string<\/div>/, @output)
    assert_match(/<div id='3'>id string<\/div>/, @output)

    assert_no_match(/<p>it failed<\/p>/, @output)
    assert_match(/<div id='2'>id string<\/div>/, @output)

    assert_match(/<div id='4'>id string<\/div>/, @output)
    assert_match(/<p>We should get this or not\?<\/p>/, @output)
    assert_match(/<p>Now maybe we shouldn't see this\?<\/p>/, @output)
    assert_match(/<p>except worked1<\/p>/, @output)
    assert_match(/<p>except worked2<\/p>/, @output)

    assert_match(/<em>Support for em tags since they have an initial start sequence similar to and &lt;esi: start\/end sequence<\/em>/, @output )
  end

  def test_content_echoing
    output = ""
    parser = ESI::CParser.new
    input = "<em>Support for em tags since they have an initial start sequence similar to and &lt;esi: start/end sequence</em>"
    parser.output_handler {|s| output << s }
    parser.process input 
    parser.finish
    assert_equal input, output
  end

  class OutputAdapter
    def initialize(output)
      @output = output
    end
    def << (msg)
      @output.call msg
    end
  end

  def test_with_tags
    sample =  @sample_file
    cache = ESI::RubyCache.new
 
    File.open('out-sample.html','w') do|output|
      parser = ESI::CParser.new
      parser.output_handler {|s| output << s }

      parser.start_tag_handler do|tag_name,attrs|
        tag = ESI::Tag::Base.create(@test_router, {}, {}, tag_name.gsub(/esi:/,''), attrs, cache)
        if parser.esi_tag
          parser.esi_tag.add_child(tag)
        else
          parser.esi_tag = tag
        end
      end

      parser.end_tag_handler do|tag_name|
        if parser.esi_tag.name == tag_name.gsub(/esi:/,'')
          parser.esi_tag.close(OutputAdapter.new(parser.output))
          parser.esi_tag = nil
        else
          parser.esi_tag.close_child(OutputAdapter.new(parser.output),tag_name)
        end
      end

      File.open(sample,'r') do|input|
        while( (buf=input.read(128)) and !input.eof? and buf.size != 0 )
          parser.process buf
        end
        parser.process buf
      end
      parser.finish
    end
    output = File.read("out-sample.html")

    assert_match(/  <div class="body">/, output)
    assert_match(/    <div>some content<\/div>/, output)
    assert_match(/    <!-- a little commentary -->/, output)
    assert_match(%q(<!-- a 
      multiline comment -->),output)
    assert_match(%q(<![CDATA[
      Some cdata fun fun fun
    ]]>), output)
    assert_match(/<!DOCTYPE html PUBLIC "-\/\/W3C\/\/DTD XHTML 1.0 Strict\/\/EN" "http:\/\/www.w3.org\/TR\/xhtml1\/DTD\/xhtml1-strict.dtd">/, output)
    assert_no_match(/<esi:/, output)
    assert_match(/<div id='1'>id string<\/div>/, output)
    assert_match(/<div id='3'>id string<\/div>/, output)

    assert_no_match(/<p>it failed<\/p>/, output)
    assert_match(/<div id='2'>id string<\/div>/, output)

    assert_match(/<div id='4'>id string<\/div>/, output)
    assert_match(/<p>We should get this or not\?<\/p>/, output)
    assert_match(/<p>Now maybe we shouldn't see this\?<\/p>/, output)
    assert_match(/<p>except worked1<\/p>/, output)
    assert_match(/<p>except worked2<\/p>/, output)
    assert_match(/<\/html>/, output)
  end

  def test_inline_parse_basics
    output = ""
    parser = ESI::CParser.new
    parser.output_handler {|s| output << s }
    tags = []
    parser.start_tag_handler do|tag_name, attrs|
      tags << {:name => tag_name, :attributes => attrs}
    end

    parser.process "<html><head><body><esi:include timeout='1' max-age='600+600' src=\"hello\"/>some more input"
    parser.process "some input<esi:include \nsrc='hello'/>some more input\nsome input<esi:include src=\"hello\"/>some more input"
    parser.process "some input<esi:inline src='hello'/>some more input\nsome input<esi:comment text='hello'/>some more input"
    parser.process "<p>some input</p><esi:include src='hello'/>some more input\nsome input<esi:include src='hello'/>some more input"
    parser.process "</body></html>"
    parser.finish
    assert_equal %Q(<html><head><body>some more inputsome inputsome more input
some inputsome more inputsome inputsome more input
some inputsome more input<p>some input</p>some more input
some inputsome more input</body></html>), output

    assert_equal 7, tags.size
    include_tags = tags.select {|tag| tag[:name] == 'esi:include'}
    assert_equal 5, include_tags.size
    include_tags.each do|tag|
      assert_equal 'hello', tag[:attributes]['src']
    end

    inline_tags = tags.select {|tag| tag[:name] == 'esi:inline'}
    assert_equal 1, inline_tags.size
    comment_tags = tags.select {|tag| tag[:name] == 'esi:comment'}
    assert_equal 1, comment_tags.size

  end

  def test_block_parser_basics
    output = ""
    parser = ESI::CParser.new
    parser.output_handler {|s| output << s }
    tags = []
    parser.start_tag_handler do|tag_name, attrs|
      tags << {:name => tag_name, :attributes => attrs}
    end
    parser.process "<html><head><body><esi:include timeout='1' max-age='600+600' src=\"hello\"/>some more input<br/>\n"
    parser.process "some input<esi:try><esi:attempt><span>some more input</span></esi:attempt><esi:except><span>\n"
    parser.process "some input</span></esi:except></esi:try>some more input<br/>\n"
    parser.process "some input<esi:inline src='hello'/>some more input\nsome input<esi:comment text='hello'/>some more input<br/>\n"
    parser.process "<p>some input</p><esi:include src='hello'/>some more input\nsome input<esi:include src='hello'/>some more input<br/>\n"
    parser.process "</body></html>"
    parser.finish
#    assert_equal %Q(some input<span>some more input</span><span>
#some input</span>some more input<br/>
#), output
    assert_equal %Q(<html><head><body>some more input<br/>
some input<span>some more input</span><span>
some input</span>some more input<br/>
some inputsome more input
some inputsome more input<br/>
<p>some input</p>some more input
some inputsome more input<br/>
</body></html>), output
  end

  def test_empty_parse
    output = ""
    parser = ESI::CParser.new
    parser.output_handler {|s| output << s }
    tags = []
    parser.start_tag_handler do|tag_name, attrs|
      tags << {:name => tag_name, :attributes => attrs}
    end
    assert_nothing_raised do
      parser.process ""
    end
    parser.finish
  end

  # it's a strange case but, we should still recongize the tag so that it can be pruned from the input stream
  def test_parser_accepts_empty_tag
    output = ""
    parser = ESI::CParser.new
    parser.output_handler {|s| output << s }
    tags = []
    parser.start_tag_handler do|tag_name, attrs|
      tags << {:name => tag_name, :attributes => attrs}
    end
    parser.process "<p>some input</p><esi:include />some more input\nsome input<esi:include src='hello'/>some more input"
    parser.finish
    assert_equal %Q(<p>some input</p>some more input
some inputsome more input), output

    assert_equal 2, tags.size
    assert_equal 'hello', tags.last[:attributes]['src']
  end

  def test_can_parse_in_chunks

    output = ""
    parser = ESI::CParser.new
    parser.output_handler {|s| output << s }
    tags = []
    parser.start_tag_handler do|tag_name, attrs|
      tags << {:name => tag_name, :attributes => attrs}
    end
    parser.process "some input<esi:in"
    parser.process "line src='hel"
    parser.process "lo'"
    parser.process "/>some more input\nsome input<esi:comment text='hello'/>some more input"
    parser.finish

    assert_equal "some inputsome more input\nsome inputsome more input", output

    assert_equal 2, tags.size
    assert_equal 'hello', tags.first[:attributes]['src']

    output = ""
    parser = ESI::CParser.new
    parser.output_handler {|s| output << s }
    tags = []
    parser.start_tag_handler do|tag_name, attrs|
      tags << {:name => tag_name, :attributes => attrs}
    end
    parser.process "some input<"
    parser.process "e"
    parser.process "s"
    parser.process "i"
    parser.process ":"
    parser.process "i"
    parser.process "n"
    parser.process "lin"
    parser.process "e"
    parser.process " "
    parser.process "s"
    parser.process "rc"
    parser.process "="
    parser.process "'hel"
    parser.process "lo'"
    parser.process "/"
    parser.process ">some more input\nsome input"
    parser.process "<esi:comment text="
    parser.process "'hello'/>some more input"
    parser.finish

    assert_equal "some inputsome more input\nsome inputsome more input", output

    assert_equal 2, tags.size
    assert_equal 1, tags.select{|tag| tag[:name] == 'esi:inline'}.size, "Failed to parse esi:inline"
    assert_equal 1, tags.select{|tag| tag[:name] == 'esi:comment'}.size, "Failed to parse esi:comment"
    assert_equal 'hello', tags.select{|tag| tag[:name] == 'esi:inline'}.first[:attributes]['src'], "Failed to parse esi:inline attributes"

  end

  def assert_totals_from_parse(parser)

    start_trys = 0
    start_attempts = 0
    start_includes = 0
    start_excepts = 0
    start_invalidates = 0

    parser.start_tag_handler do|tag_name,attrs|
    #  puts "\tstart: #{tag_name.inspect}#{attrs.inspect}"
      case tag_name
      when "esi:try" then start_trys += 1
      when "esi:attempt" then start_attempts += 1
      when "esi:include" then start_includes += 1
      when "esi:except" then start_excepts += 1
      when "esi:invalidate" then start_invalidates += 1
      else
        raise "Unverified start: #{tag_name.inspect}#{attrs.inspect}"
      end
    end

    end_trys = 0
    end_attempts = 0
    end_includes = 0
    end_excepts = 0
    end_invalidates = 0

    parser.end_tag_handler do|tag_name|
      #puts "\tend: #{tag_name.inspect}"
      case tag_name
      when "esi:try" then end_trys += 1
      when "esi:attempt" then end_attempts += 1
      when "esi:include" then end_includes += 1
      when "esi:except" then end_excepts += 1
      when "esi:invalidate" then end_invalidates += 1
      else
        raise "Unverified start: #{tag_name.inspect}"
      end
    end

    yield 

    assert_equal 2, start_trys, "More or less esi:try tags detected #{start_trys.inspect}"
    assert_equal 2, start_attempts, "More or less esi:attempt tags detected #{start_attempts.inspect}"
    assert_equal 6, start_includes, "More or less esi:include tags detected #{start_includes.inspect}"
    assert_equal 2, start_excepts, "More or less esi:except tags detected #{start_excepts.inspect}"
    assert_equal 1, start_invalidates, "More or less esi:invalidate tags detected #{start_invalidates.inspect}"
    assert_equal 2, end_trys, "More or less esi:try tags detected #{end_trys.inspect}"
    assert_equal 2, end_attempts, "More or less esi:attempt tags detected #{end_attempts.inspect}"
    assert_equal 6, end_includes, "More or less esi:include tags detected #{end_includes.inspect}"
    assert_equal 2, end_excepts, "More or less esi:except tags detected #{end_excepts.inspect}"
    assert_equal 1, end_invalidates, "More or less esi:invalidate tags detected #{end_invalidates.inspect}"
  end

  def test_sample
    sample =  @sample_file
    output = ""
    parser = ESI::CParser.new
    parser.output_handler {|s| output << s }
    assert_totals_from_parse( parser ) do
      parser.process File.read(sample)
      parser.finish
    end
    assert_no_match /<esi:/, output

    #8.times do|i|
      i = 4
      File.open(sample,'r') do|input|
        output = ""
        parser = ESI::CParser.new
        parser.output_handler {|s| output << s }
        assert_totals_from_parse( parser ) do
          while( (buf=input.read((i+1)*2)) and !input.eof? and buf.size != 0 )
            parser.process buf
          end
          parser.process buf
          parser.finish
        end
        assert_no_match /<esi:/, output
      end
#    end

  end

  def test_embedded_content
input = %Q(
<html>
<head>
</head>
<body>
  <h1>This is a test document</h1>
  <esi:try>
    <esi:attempt>
      <div>Some content before</div><esi:include src="/fragments/test1.html" max-age="600+600"/>
    </esi:attempt>
    <esi:except>
      <esi:include src="/fragments/test_failover.html"/>
    </esi:except>
  </esi:try>
</body>
</html>)
    output = ""
    parser = ESI::CParser.new
    parser.output_handler {|s| output << s }
    starts = 0
    ends = 0
    parser.start_tag_handler do|tag_name, attrs|
      starts += 1
    end
    parser.end_tag_handler do|tag_name|
      ends += 1
    end
    parser.process input
    parser.finish
    assert_equal 5, starts, "Start tags"
    assert_equal 5, ends, "End tags"
  end

  def test_basic_invalidate_tag
      parser_input = %Q(<html><body>
      <esi:invalidate output="no">
           <?xml version="1.0"?>
           <!DOCTYPE INVALIDATION SYSTEM "internal:///WCSinvalidation.dtd">
           <INVALIDATION VERSION="WCS-1.1">
             <OBJECT>
               <BASICSELECTOR URI="/foo/bar"/>
               <ACTION REMOVALTTL="0"/>
               <INFO VALUE="invalidating fragment test 1"/>
             </OBJECT>
           </INVALIDATION>
      </esi:invalidate>
      <esi:invalidate output="no">
        <?xml version="1.0"?>
        <!DOCTYPE INVALIDATION SYSTEM "internal:///WCSinvalidation.dtd">
        <INVALIDATION VERSION="WCS-1.1">
          <OBJECT>
            <BASICSELECTOR URI="/foo/bar"/>
            <ACTION REMOVALTTL="0"/>
            <INFO VALUE="invalidating fragment test 2"/>
          </OBJECT>
        </INVALIDATION>
      </esi:invalidate>
</body></html>)
    output = ""
    parser = ESI::CParser.new
    parser.output_handler {|s| output << s }
    start_called = false
    end_called = false
    parser.start_tag_handler do|tag_name, attrs|
      start_called = true
    end
    parser.end_tag_handler do|tag_name|
      end_called = true
    end
    parser.process parser_input
    parser.finish
    assert start_called
    assert end_called
  end

  def test_attribute_values
    output = ""
    parser = ESI::CParser.new
    parser.output_handler {|s| output << s }
    parser.process 'start:<esi:include src="foobar?hi=cool"/>:finish'
    parser.finish
    assert_equal "start::finish", output
    output = ""
    parser.process 'start:<esi:include src="foo bar"/>:finish'
    parser.finish
    assert_equal "start::finish", output
    output = ""
    parser.process 'start:<esi:include src="foobar?hi=!@#$%^&*()-+~`"/>:finish'
    parser.finish
    assert_equal "start::finish", output
    output = ""
    parser.process 'start:<esi:try src="foobar?hi=!@#$%^&*()-+~`">cool</esi:try>:finish'
    parser.finish
    assert_equal "start:cool:finish", output
    output = ""
    parser.process 'start:<esi:try>cool</esi:try>:finish'
    parser.finish
    assert_equal "start:cool:finish", output
  end

#  def test_setup
#    puts @output
#  end

end
