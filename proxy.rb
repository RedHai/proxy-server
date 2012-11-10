require 'socket'
require 'uri'

class Proxy
  def run(port)
    begin
      do_run_action(port)
    rescue Interrupt
      puts 'Got Interrupt ...'
    ensure
      do_clean_up_action
    end
  end

  private 

  def do_run_action(port)
    puts "Listen at localhost:#{port}"
    @socket = TCPServer.new(port)
    loop do
      s = @socket.accept
      Thread.new(s, &method(:handle_request))
    end
  end

  def handle_request(to_client)
    request_line = to_client.readline

    verb = request_line[/^\w+/]
    url = request_line[/^\w+\s+(\S+)/, 1]
    version = request_line[/HTTP\/(1\.\d)\s*$/, 1]
    uri = URI::parse(url)

    puts((" %4s "%verb) + url)

    to_server = TCPSocket.new(uri.host, (uri.port.nil? ? 80 : uri.port))
    to_server.write("#{verb} #{uri.path}?#{uri.query} HTTP/#{version}\r\n")

    content_len = 0

    loop do
      line = to_client.readline

      if line =~ /^Content-Length:\s+(\d+)\s*$/
        content_len = $1.to_i
      end

      if line =~ /^proxy/i
        next
      elsif line.strip.empty?
        to_server.write("Connection: close\r\n\r\n")

        if content_len >= 0
          to_server.write(to_client.read(content_len))
        end

        break
      else
        to_server.write(line)
      end
    end

    buff = ''
    loop do
      to_server.read(4048, buff)
      to_client.write(buff)
      break if buff.size < 4048
    end

    to_client.close
    to_server.close

  end

  def do_clean_up_action
    if @socket
      @socket.close
      puts 'Socket closed..'
    end
    puts 'Quitting.'
  end
  
end

if ARGV.empty?
  port = 8088
elsif ARGV.size == 1
  port = ARGV[0].to_i
else
  puts 'Usage : proxy.rb [port]'
  exit 1
end

Proxy.new.run port
