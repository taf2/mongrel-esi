Merb::Router.prepare do |r|
  r.match('/').to(:controller => 'simple', :action =>'index')
end
class Simple < Merb::Controller
  TTL=1
  TTL2=3
  XFACTOR=4096
  def index
    @headers["Surrogate-Control"] = %{content="ESI/1.0", max-age=10}
   %Q(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>This is a test</title></head><body>
  #{'x'*XFACTOR}
  line 1: <pre><esi:try><esi:attempt><esi:include max-age='#{TTL2}' src='/frag1'/></esi:attempt><esi:except>line 1 failed</esi:except></esi:try></pre>
  some more bytes here
  #{'x'*XFACTOR}
  line 2: <pre><esi:try><esi:attempt><esi:include max-age='#{TTL}' src='/frag2'/></esi:attempt><esi:except>line 1 failed</esi:except></esi:try></pre>
  and some more here
  #{'x'*XFACTOR}
  some more bytes here
  line 3: <pre><esi:try><esi:attempt><esi:include max-age='#{TTL2}' src='/frag3'/></esi:attempt><esi:except>line 1 failed</esi:except></esi:try></pre>
  and some more here
  #{'x'*XFACTOR}
  some more bytes here
  line 4: <pre><esi:try><esi:attempt><esi:include max-age='#{TTL}' src='/frag4'/></esi:attempt><esi:except>line 4 failed</esi:except></esi:try></pre>
  #{'x'*XFACTOR}
  line 5: <pre><esi:try><esi:attempt><esi:include max-age='#{TTL}' src='/frag1'/></esi:attempt><esi:except>line 5 failed</esi:except></esi:try></pre>
  #{'x'*XFACTOR}
  line 6: <pre><esi:try><esi:attempt><esi:include max-age='#{TTL2}' src='/frag2'/></esi:attempt><esi:except>line 6 failed</esi:except></esi:try></pre>
  line 7: <pre><esi:try><esi:attempt><esi:include max-age='#{TTL}' src='/frag4'/></esi:attempt><esi:except>line 7 failed</esi:except></esi:try></pre>
  #{'x'*XFACTOR}
  and some more here
  line 8: <pre><esi:include max-age='#{TTL2}' src='/frag1'/></pre>
  #{'x'*XFACTOR}
  and some more here
  some more bytes here
  line 9: <pre><esi:include max-age='#{TTL2}' src='/frag3'/></pre>
  #{'x'*XFACTOR}
  and some more here
</body></html>)
  end

end

Merb::Config.use { |c|
  c[:framework]           = {},
  c[:session_store]       = 'none',
  c[:exception_details]   = true
}
