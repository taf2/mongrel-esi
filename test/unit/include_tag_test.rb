require File.join(File.dirname(__FILE__),'help.rb')

class IncludeTagTest < Test::Unit::TestCase
  include TestServer
  def test_close

    output = ""
    include_tag = ESI::Tag::Base.create(@test_router, {}, {},
                                        'include', {'src'=>"/test/success/"},
                                        ESI::RubyCache.new)
    include_tag.close(output)
    assert_equal("<div>hello there world</div>",output)
  end
end
