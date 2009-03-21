# Copyright (c) 2008 Todd A. Fisher
# see LICENSE
require 'rubygems'
gem 'hpricot'
require 'hpricot'

module ESI
  module Tag
    class Invalidate < Base
      def initialize(uri,headers,http_params,name,attrs,cache)
        super
        @buffer = ""
      end
      def close( output, options = {} )
        xml = Hpricot.XML(@buffer)

        (xml/:OBJECT).each do|object|
          selector = (object % :BASICSELECTOR)
          advanced_selector = (object % :ADVANCEDSELECTOR)
          if selector
            action = (object % :ACTION)
            info = (object % :INFO)
            uri = selector[:URI]
            remove_ttl = action[:REMOVALTTL].to_i
            @cache.keys do |key,fragment|
              if fragment.uri.match(uri)
                @cache.delete_unlocked( key )
              end
            end
          elsif advanced_selector
            # XXX: this code is untested!
            # NOTE: our support of both advanced and basic is a little off
            # we'll probably invalidate more then is normally done by the standard
            # also when we switch to memcache this will be much harder to support this flexibilty
            uri_prefix = advanced_selector[:URIPREFIX]
            uri_regex = advanced_selector[:URIEXP]
            @cache.keys do |key,data|
              if key.match(uri_prefix) and key.match(uri_regex)
                puts "invalidating #{uri}"
                # XXX: this code is untested!
                @cache.delete_unlocked( key, remove_ttl )
              end
            end
            # XXX: this code is untested!
          end
        end
        @cache.sweep!

      end
      def buffer( output, inner_html )
        # expects ^/<![CDATA[/
        @buffer << inner_html
      end
    end
  end
end
