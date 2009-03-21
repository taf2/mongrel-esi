# Copyright (c) 2008 Todd A. Fisher
# see LICENSE

require 'esi/logger'
require 'esi/tag/container'

module ESI
  module Tag
    class Try < Container
 
      def close( output )
        super(output)
        begin
          @children.each do |tag|
            if tag.name == "attempt"
              tag.children.each do|ctag|
                ctag.close( output, :raise => true )
              end
            end
          end
        rescue => e
          log_error e.message
          @children.each do |tag|
            if tag.name == "except"
              tag.children.each_with_index do|ctag,index|
                output << tag.buffers[index]
                ctag.close( output )
              end
              output << tag.buffers[tag.children.size]
            end
          end
        end
      end

      def buffer( output, inner_html )
        @unclosed.buffer( output, inner_html ) if @unclosed
      end

    end
  end
end
