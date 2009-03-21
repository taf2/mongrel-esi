# Copyright (c) 2008 Todd A. Fisher
# see LICENSE
require 'esi/logger'
require 'esi/tag/base'

module ESI
  module Tag
    class Container < ESI::Tag::Base
      include ESI::Log
      extend ESI::Log
      attr_reader :children, :name, :closed, :cache

      def initialize(router,headers,http_params,name,attrs,cache)
        super
        @children = []
        @unclosed = nil
      end

      def close_child( output, name )
        name = name.sub(/esi:/,'')
        if @unclosed and @unclosed.name == name
          @unclosed.close( output )
          @unclosed = nil
        end
      end

      def add_child(tag)
        if @unclosed
          #puts "add as child of(#{self.name}): #{tag.name} #{tag.attributes.inspect} to #{@unclosed.name}"
          @unclosed.add_child(tag)
        else
          #puts "add: #{tag.name} #{tag.attributes.inspect} to #{self.name}"
          @unclosed = tag if tag.respond_to?(:add_child)
          @children << tag
        end
      end

    end
  end
end
