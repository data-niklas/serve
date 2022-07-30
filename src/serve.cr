require "option_parser"
require "http/server"
require "cor"
require "cor/string"
require "flate"
require "gzip"


class String

  def border_line : String
    length = 0
    self.each_line do |line|
      if line.size > length
        length = line.size
      end
    end
    return "-".*(length + 2).faint
  end

  def format_self : self
    res = String::Builder.new
    self.each_line do |line|
      if !res.empty?
        res << "\n"
      end
      res << " "
      res << line
    end
    res.to_s
  end

  def info : self
    side = border_line()
    side + "\n" + format_self() + "\n" + side 
  end

  def error : self
    side = border_line()
    side + "\n" + format_self().fore(:red) + "\n" + side 
  end

  def success : self
    side = border_line()
    side + "\n" + format_self().fore(:green) + "\n" + side 
  end
end

def cache_request?(context : HTTP::Server::Context, last_modified : Time) : Bool
  # According to RFC 7232:
  # A recipient must ignore If-Modified-Since if the request contains an If-None-Match header field
  if if_none_match = context.request.if_none_match
    match = {"*", context.response.headers["Etag"]}
    if_none_match.any? { |etag| match.includes?(etag) }
  elsif if_modified_since = context.request.headers["If-Modified-Since"]?
    header_time = HTTP.parse_time(if_modified_since)
    # File mtime probably has a higher resolution than the header value.
    # An exact comparison might be slightly off, so we add 1s padding.
    # Static files should generally not be modified in subsecond intervals, so this is perfectly safe.
    # This might be replaced by a more sophisticated time comparison when it becomes available.
    !!(header_time && last_modified <= header_time + 1.second)
  else
    false
  end
end




def etag(modification_time)
  %{W/"#{modification_time.to_unix}"}
end

def add_cache_headers(response_headers : HTTP::Headers, last_modified : Time) : Nil
  response_headers["Etag"] = etag(last_modified)
  response_headers["Last-Modified"] = HTTP.format_time(last_modified)
end

def modification_time(file_path)
  File.info(file_path).modification_time
end

def file_included(file_path, excluding)
  ext = file_path.extension.sub(".","")
  excluding.each do |excluded|
    if excluded == ext
      return true
    end
  end
  return false
end

def directory_listing(io, request_path, path)
  HTTP::StaticFileHandler::DirectoryListing.new(request_path.to_s, path.to_s).to_s(io)
end


path = Path["./"]
port = "8080"
cors = false
list_dirs = true
compress = false
excluding = [] of String

OptionParser.parse do |parser|

  parser.on "-e=FILES", "--exclude=FILES", "Exclude" do |files|
    excluding = files.split(",")
  end

  parser.on "-p=PORT", "--port=PORT", "Port" do |prt|
    port = prt
  end


  parser.on "-c", "--cors", "CORS" do
    cors = true
  end

  parser.on "-x", "--compress", "Compress files with GZIP or Flate" do
    compress = true
  end

  parser.on "-d", "--dirs", "Don't list directories" do
    list_dirs = false
  end

  parser.on "-h", "--help", "Help" do
    puts parser
    exit
  end

  parser.unknown_args do |args_arr|
    if args_arr.size > 0
      path = Path[args_arr[0]]
    end

  end
end

path = path.expand(home: true).normalize


handlers : Array(HTTP::Handler) = [] of HTTP::Handler
handlers << HTTP::ErrorHandler.new
handlers << HTTP::LogHandler.new
if compress
  handlers << HTTP::CompressHandler.new
end
server = HTTP::Server.new(handlers) do |context|

  res = context.response
  if context.request.method == "GET"
    file_path = path.join(context.request.path)

    if File.exists? file_path
      if Dir.exists? file_path
        if list_dirs
          res.content_type = "text/html"
          directory_listing(res, context.request.path, file_path)
        else
          # No permission to view the content of the directory
          res.status = HTTP::Status::NOT_FOUND
          res.print "File not found"
        end
      else

        ext = file_path.extension.sub(".", "")
        found = file_included(file_path, excluding)
        if found
          # Filetype was excluded
          res.status = HTTP::Status::NOT_FOUND
          res.print "File not found"
        else

          # Caching
          last_modified = modification_time(file_path)
          add_cache_headers(res.headers, last_modified)

          if cache_request?(context, last_modified)
            res.status = :not_modified
            next
          end

          # CORS
          if cors
            res.headers["Access-Control-Allow-Origin"] = "*"
          end

          res.content_type = MIME.from_filename(file_path.to_s, "application/octet-stream")
          request_headers = context.request.headers

          res.content_length = File.size(file_path)
          IO.copy(File.new(file_path), res)
            
            
        end

      end
    else
      # File does not exist
      res.status = HTTP::Status::NOT_FOUND
      res.print "File not found"
    end
  else
    # Only the GET method
    res.status = HTTP::Status::NOT_IMPLEMENTED
    res.print "Only the GET method is supported"
  end
end

address = server.bind_tcp port.to_i
puts ("Serving files\nfrom #{path.to_s.bold}\non " + "http://#{address}".bold).info
if excluding.size > 0
  excluded_files = String::Builder.new
  excluded_files << " Excluding:"
  excluding.each do |exclude|
    excluded_files << " "
    excluded_files << exclude
  end
  puts excluded_files.to_s.bold
end
server.listen