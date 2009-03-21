require 'mongrel/handlers.rb'
require 'digest/md5'

#
# Allow files to be servered from multiple directories within a single URL space
#
# This is sometimes very useful when working with multiple application servers, each with
# their own set of static files.
#
# Usage:
#   
#   uri "/request_path/", :handler => MultiDirHandler.new(['/file/path1','/file/path2'])
#
# options:
#   :cwd, override the server root directory, make sure there is a tmp directory in server root
#
class MultiDirHandler < Mongrel::DirHandler
  # check in each folder for the file
  def initialize( path, options = {})
    @server_root = (options[:cwd] || SERVER_ROOT)
    @paths = path.flatten
    super(@paths[0])
  end

  # check each folder
  def can_serve(path_info)
    if check_multifile_request( path_info )
      return handle_multifile_request( path_info )
    else
      @paths.each do|path|
        @path = File.expand_path(path)
        ret = super(path_info)
        return ret unless ret.nil?
      end
    end
    @path = @paths[0]
    return nil
  end
    
  def send_file(req_path, request, response, header_only=false)
    if check_multifile_request( req_path )
      # change the request path
      req_path = cached_filepath( req_path )
    end
    super( req_path, request, response, header_only )
  end

private

  def check_multifile_request(path_info)
    path_info.match( /\.css,/ )
  end

  def cached_filepath(req_path)
    files = req_path.split(',')
    digest = Digest::MD5.hexdigest(req_path)
    "#{@server_root}/tmp/cache-#{digest}#{File.extname(files.first)}"
  end
 
  # this special method will process urls in the form
  # file,file,file, storing a cache copy of the combined files in #{RAILS_ROOT}/tmp/rhg-ui-cache/
  # accelerating local development
  def handle_multifile_request(path_info)
    # visit each of the files in the list compute the max lastmodified time stamp
    # use this value to determine if the cache file needs to be recreated.  e.g. whether a CSS or JS file has been edited
    begin
      files = path_info.split(',')
      cache_file = cached_filepath( path_info )
      File.open( cache_file, "wb" ) do|out|
        files.each do |file|
          path = "/stylesheets/#{file}".squeeze("/")
          out << "@import '#{path}?#{Time.now.to_i}';\n"
        end
      end
      return cache_file
    rescue => e
      puts e.message
      puts e.backtrace
    end
    return nil
  end

end
