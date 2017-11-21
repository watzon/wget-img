require "./wget-img/*"
require "option_parser"
require "http/client"
require "crystagiri"

version : Bool = false
out_dir : String = "./"
scrape_url : String? = nil

OptionParser.parse! do |parser|
  parser.banner = "Usage: wget-img [arguments]"
  parser.on("-v", "--version", "Display the wget-img version") { version = true }
  parser.on("-u URL", "--url=URL", "Set the url to fetch [required]") { |url| scrape_url = url }
  parser.on("-o OUT", "--out=OUT", "Set the out directory. [default .]") { |out| out_dir = out }
  parser.on("-h", "--help", "Show this message") { puts parser }
end

if version
  puts "wget-img v0.1.0"
end

if !scrape_url
  puts "A URL is required. Set it with the '-u' flag."
  exit
end

def download(url, max_redirects = 3) : String?
  response = HTTP::Client.get(url)

  if max_redirects == 0
    puts "Redirect limit reached"
    return
  end

  if response.status_code >= 200 && response.status_code < 300
    # Looks like it was successful
    if response.body?
      return response.body
    else
      # For some reason there was no body though
      return
    end
  elsif response.status_code >= 300 && response.status_code < 400
    # Looks like we've hit a redirect. Gather the redirect url and try again.
    redir_to = response.headers["Location"]?
    if !redir_to
      return
    else
      return download(redir_to, max_redirects - 1)
    end
  else
    # 400 or 500 is no good for us. Nothing to download.
    return
  end
end

def write_file!(file, body, overwrite = false)

  if !Dir.exists?(File.dirname(file))
    Dir.mkdir_p(File.dirname(file), 0o755)
  end

  if File.exists?(file) && !overwrite
    puts "File at '#{file}'' already exists and overwite is set to false. Skipping."
    return false
  end

  File.write(file, body)
  puts "Wrote file to '#{file}'"
  return true
end

doc = Crystagiri::HTML.from_url scrape_url.as(String)
doc.where_tag("img") do |tag|
  src = tag.node["src"]?
  if src
    src = src.as(String)
    uri = URI.parse(src)
    img_url = uri.host ? uri.to_s : File.join(scrape_url.as(String), src)
    
    body = download(img_url)

    if body
      out_filename = File.join(out_dir, File.basename(img_url))
      write_file!(out_filename, body)
    end
  end
end
