# Copyright (c) 2008 Todd A. Fisher
# see LICENSE
require 'esi/esi'
require 'esi/tag/base'
require 'esi/tag/include'
require 'esi/tag/invalidate'
require 'esi/tag/attempt'
require 'esi/tag/except'
require 'esi/tag/try'
require 'esi/tag/vars'
require 'esi/tag/remove'

module ESI
  class Parser < CParser
    attr_reader :response

    def initialize( output, router, cache, max_depth )
      super()
      @router = router
      @cache = cache
      @max_depth = max_depth
      @response = ESI::Response.new( output )
 
      end_tag_handler do|tag_name|
        #puts "rb end #{tag_name.inspect}"
        if self.esi_tag.name == tag_name.sub(/esi:/,'')

          if tag_name.match(/try|include/) # run these in parallel
            tag = self.esi_tag.clone
            tag_buffer = @response.partial_buffer

            #puts "start #{tag_name}"
            thread = Thread.new(tag,tag_buffer) do|tag,buffer|
              begin
                tag.close(buffer)
              ensure
                buffer.close_write
                #puts "finish #{tag_name}"
              end
            end
            @response.wait_thread( thread )
          else
            self.esi_tag.close( @response.active_buffer )
          end

          self.esi_tag = nil

        else
          self.esi_tag.close_child(self.output,tag_name)
        end
      end
    end

    def prepare( request_params, http_params )
      start_tag_handler do|tag_name, attrs|
        #puts "rb start #{tag_name.inspect}"
        tag = ESI::Tag::Base.create( @router,
                                     request_params,
                                     http_params,
                                     tag_name.gsub(/esi:/,''),
                                     attrs,
                                     @cache )
        # set the tag depth
        tag.depth = self.depth if tag.respond_to?(:depth=)
        tag.max_depth = @max_depth if tag.respond_to?(:max_depth=)

        if self.esi_tag and self.esi_tag.respond_to?(:add_child)
          self.esi_tag.add_child(tag)
        else
          self.esi_tag = tag
        end
      end
      self.output_handler do|chars|
        @response.active_buffer << chars
        @response.send
      end
    end

    def finish
      super
      @response.flush
    end

  end
end
