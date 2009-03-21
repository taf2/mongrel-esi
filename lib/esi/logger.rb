require 'logger'

module ESI
  module Log

    if ENV["test"] == "true"
      $logger ||= Logger.new("log/test.log")
      $logger.instance_eval do
        def puts( msg )
          debug( msg )
        end
        def print( msg )
          debug( msg )
        end
      end
    end

    def log( io, msg )
      io.puts msg
    end
 
    def msg( io, msg )
      io.print msg
    end

    def log_request( msg )
      msg( $logger || STDERR, msg )
    end

    def log_debug( msg )
      log( $logger || STDERR, msg )
    end

    def log_error( msg )
      log( $logger || STDERR, msg )
    end

  end
end
