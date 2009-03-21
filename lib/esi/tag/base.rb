# Copyright (c) 2008 Todd A. Fisher
# see LICENSE
require 'esi/logger'

module ESI
  module Tag
    class Base
      Validate = ['try','attempt','except','include','invalidate','vars','remove']
      attr_reader :attributes, :children, :name, :closed, :cache
 
      include ESI::Log

      def initialize(router,headers,http_params,name,attrs,cache)
        @router = router
        @headers = headers
        @http_params = http_params
        @attributes = attrs
        @cache = cache
        @name = name
      end
 
      def self.create(router,headers,http_params,tag_name,attrs,cache)
        raise "Unsupport ESI tag: #{tag_name}" unless Validate.include?(tag_name)
        eval(tag_name.sub(/esi:/,'').capitalize).new(router,headers,http_params,tag_name,attrs,cache)
      rescue => e
        log_debug "Failed while creating tag: #{tag_name}, with error: #{e.message}"
        raise e
      end

      def buffer( output, inner_html )
        if output.respond_to?("<<")
          output << inner_html
        else
          output.call inner_html
        end
      end

      def close( output, options = {} )
      end

      # :startdoc:
      # scans the fragment url, replacing occurrances of $(VAR{ ..  with the given value read from
      # the HTTP Request object
      # :enddoc:
      def prepare_url_vars(url)
        # scan url  for $(VAR{
        # using the regex look for url vars that get set via http params
        # for each var extract the value and store it in the operations array
        operations = []
        url.scan(/\$\([0-9a-zA-Z_{'}]+\)/x) do|var|
          # extract the var name
          name = var.gsub(/\$\(/,'').gsub(/\{.*$/,'')
          key = var.gsub(/^.*\{/,'').gsub(/\}.*$/,'').gsub(/['"]/,'')
          #puts "[#{key}]:[#{name}] from #{var}, check if #{Mongrel::HttpRequest.query_parse(@headers[name]).inspect}"
          value = Mongrel::HttpRequest.query_parse(@headers[name])[key]
          operations << {:sub => var, :with => (value||"")}
        end
        # apply each operation to the url
        operations.each { |op| url.gsub!(op[:sub],op[:with]) }
        url
      end

    end
  end
end
