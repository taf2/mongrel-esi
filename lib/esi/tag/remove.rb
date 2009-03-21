# Copyright (c) 2008 Todd A. Fisher
# see LICENSE
#
# The esi:remove tag allows markup to removed when ESI processing is enabled.
#
# <esi:remove>
#   <a href="http://www.example.com">www.example.com</a>
# </esi:remove>
#
require 'uri'
require 'net/http'
require 'esi/parser'

module ESI
  module Tag
    class Remove < Base
      def buffer( output, inner_html )
      end

      def close( output, options = {} )
      end
    end
  end
end
