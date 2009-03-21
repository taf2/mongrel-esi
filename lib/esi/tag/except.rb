# Copyright (c) 2008 Todd A. Fisher
# see LICENSE
require 'esi/tag/container'

module ESI
  module Tag
    class Except < Container
      attr_reader :buffers

      def initialize(uri,headers,http_params,name,attrs,cache)
        super
        @buffers = [] # buffer output since this may only appear if the attempt block fails first
        @buffer_index = 0
        @buffers[@buffer_index] = ""
      end

      def add_child(tag)
        super(tag)
        @buffer_index += 1
        @buffers[@buffer_index] = ""
      end

      def buffer( output, inner_html )
        @buffers[@buffer_index] << inner_html
      end
    end
  end
end
