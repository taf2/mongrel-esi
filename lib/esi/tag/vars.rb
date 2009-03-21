# Copyright (c) 2008 Todd A. Fisher
# see LICENSE
#
# The esi:vars tag allows markup outside other ESI blocks to be evaluated for ESI variables
#
# <esi:vars>
#   <img src="/tracking?user_id=$(HTTP_COOKIE{'i'})"/>
# </esi:vars>
#
require 'uri'
require 'net/http'
require 'esi/parser'

module ESI
  module Tag
    class Vars < Base
      def initialize(router,headers,http_params,name,attrs,cache)
        super
        @var_buffer = ""
      end

      def buffer( output, inner_html )
        @var_buffer << inner_html
      end

      def close( output, options = {} )
        super(output)
        output << prepare_url_vars( @var_buffer )
      end
    end
  end
end
