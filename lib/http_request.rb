#!/usr/bin/env ruby
#
# == Description
#
#   This is a small, lightweight, powerful HttpRequest class based on the 'net/http' and 'net/ftp' libraries, 
#   it's easy to use to send http request and get response, also can use it as a shell script in command line.
#
# == Example
#
#   Please read README.rdoc
#
# == Version
# 
#   v1.0.1
#
#   Last Change: 11 Apail, 2009
#
# == Author
#
#   xianhua.zhou<xianhua.zhou@gmail.com>
#   homepage: http://my.cnzxh.net
#
#
require 'net/http'
require 'net/https'
require 'cgi'
require 'singleton'

class HttpRequest
	include Singleton

	def self.http_methods
    %w{get head post put proppatch lock unlock options propfind delete move copy mkcol trace}
	end

  # initialize
	def init_args(method, options)
		options = {:url => options.to_s} if [String, Array].include? options.class
		@options = {
			:ssl_port        => 443,
			:redirect_limits => 5,
			:redirect        => true,
			:url             => nil
		}
		@options.merge!(options)
		@uri = URI(@options[:url])
    @uri.path = '/' if @uri.path.empty?
		@headers = {
      'Host' => @uri.host,
      'Referer' => @options[:url],
      'Accept-Language' => 'en-us,zh-cn;q=0.7,en;q=0.3',
      'Accept-Charset' => 'zh-cn,zh;q=0.5',
      'Accept' => 'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5',
      'Cache-Control' => 'max-age=0',
      'User-Agent' => 'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.0.7) Gecko/2009030423 Ubuntu/8.04 (hardy) Firefox/3.0.7',
      'Connection' => 'keep-alive'
		}

    # Basic Authenication
    @headers['Authorization'] = "Basic " + [@uri.userinfo].pack('m').delete!("\r\n") if @uri.userinfo

    # headers
    @options[:headers].each {|k, v| @headers[k] = v} if @options[:headers].is_a? Hash

    # add cookies if have
    if @options[:cookies]
      if @options[:cookies].is_a? Hash
        cookies = []
        @options[:cookies].each {|k, v|
          cookies << "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"
        }
        cookies = cookies.join('; ')
      else
        cookies = @options[:cookies].to_s
      end
      @headers['Cookie'] = cookies unless cookies.empty?
    end

    @redirect_times = 0 if @options[:redirect]
	end

  # send request
	def request(method, opt, &block)
		init_args(method, opt)
		@options[:method] = method

    # for upload files
    if @options[:files].is_a?(Array) && 'post'.eql?(method)
      build_multipart
    else
      if @options[:parameters].is_a? Hash
        @options[:parameters] = @options[:parameters].collect{|k, v| 
          CGI.escape(k.to_s) + '=' + CGI.escape(v.to_s)
        }.join('&')
      end
    end

		http =  if @options[:proxy_addr]
      if @options[:proxy_user] and @options[:proxy_pass]
        Net::HTTP::Proxy(@options[:proxy_addr], @options[:proxy_port], @options[:proxy_user], @options[:proxy_pass]).new(@u.host, @u.port)
      else
        Net::HTTP::Proxy(@options[:proxy_addr], @options[:proxy_port]).new(@uri.host, @uri.port)
      end
    else
      Net::HTTP.new(@uri.host, @uri.port)
    end

		# ssl support
		http.use_ssl = true if @uri.scheme =~ /^https$/i

		# sending request and get response 
		response = send_request http

		return data(response, block) unless @options[:redirect]

		# redirect....===>>>
		case response
		when Net::HTTPRedirection
			@options[:url] = if response['location'] =~ /^http[s]*:\/\//i
        response['location']
      else
        @uri.scheme + '://' + @uri.host + ':' + @uri.port.to_s + response['location']
      end
			@redirect_times = 0 unless @redirect_times
			@redirect_times = @redirect_times.succ
			raise 'too deep redirect...' if @redirect_times > @options[:redirect_limits]
			request('get', @options)
		else
			return data(response, block)
		end
	end

	def data(response, block)
		block.is_a?(Proc) ? block.call(response) : response
	end

  # for ftp
  def self.ftp(method, options, &block)
    require 'net/ftp'
    options = {:close => true}.merge(options)
    options[:url] = "ftp://#{options[:url]}" unless options[:url] =~ /^ftp:\/\//
    uri = URI(options[:url])
    guest_name, guest_pass = 'anonymous', 'guest@' + uri.host
    unless options[:username]
      options[:username], options[:password] = uri.userinfo ? uri.userinfo.split(':') : [guest_name, guest_pass]
    end
    options[:username] = guest_user unless options[:username]
    options[:password] = guest_pass unless options[:password]
    ftp = Net::FTP.open(uri.host, options[:username], options[:password])
    return data(ftp, block) unless method
    stat = case method.to_sym
           when :get
             options[:to] = File.basename(uri.path) unless options[:to]
             ftp.getbinaryfile(uri.path, options[:to])
           when :put
             ftp.putbinaryfile(options[:from], uri.path)
           when :mkdir, :rmdir, :delete, :size, :mtime, :list, :nlst
             ftp.method(method).call(uri.path)
           when :rename
             ftp.rename(uri.path, options[:to]) if options[:to]
           when :status
             ftp.status
           else
             return ftp
           end
    if options[:close] && !block
      ftp.close
      stat
    else
      ftp.response = stat
      return data(ftp, block)
    end
  end

  # catch all of http requests
	def self.method_missing(method_name, args, &block)
		method_name = method_name.to_s.downcase
		raise NoHttpMethodException, "No such http method can be called: #{method_name}" unless self.http_methods.include?(method_name)
		self.instance.request(method_name, args, &block)
	end

	private

  # for upload files by post method
  def build_multipart
    require 'md5'
    boundary = MD5.md5(rand.to_s).to_s[0..5]
    @headers['Content-type'] = "multipart/form-data, boundary=#{boundary}"
    multipart = []
    if @options[:parameters]
      @options[:parameters] = CGI.parse(@options[:parameters]) if @options[:parameters].is_a? String
      if @options[:parameters].is_a? Hash
        @options[:parameters].each {|k, v| 
          multipart << "--#{boundary}" 
          multipart << "Content-disposition: form-data; name=\"#{CGI.escape(k.to_s)}\"" 
          multipart << "\r\n#{CGI.escape(v.to_s)}"
        }
      end
    end
    @options[:files].each_with_index {|f, index|
      f[:field_name] ||= "files[]"
      f[:file_name] ||= "#{boundary}_#{index}"
      f[:transfer_encoding] ||= "binary"
      f[:content_type] ||= 'application/octet-stream'
      multipart << "--#{boundary}" 
      multipart << "Content-disposition: form-data; name=\"#{f[:field_name]}\"; filename=\"#{f[:file_name]}\""
      multipart << "Content-type: #{f[:content_type]}"
      multipart << "Content-Transfer-Encoding: #{f[:transfer_encoding]}"
      multipart << "\r\n#{f[:file_content]}"
    }
    multipart << "--#{boundary}--"
    multipart = multipart.join("\r\n")
    @headers['Content-length'] = "#{multipart.size}"
    @options[:parameters] = multipart
  end

  # send request
	def send_request(http)
		case @options[:method]
		when /^(get|head|options|delete|move|copy|trace|)$/
			@options[:parameters] = @uri.query.to_s if @options[:parameters].to_s.empty?
			@options[:parameters] = "?#{@options[:parameters]}" unless @options[:parameters].empty?
			http.method(@options[:method]).call("#{@uri.path}#{@options[:parameters]}", @headers)
		else
			http.method(@options[:method]).call(@uri.path, @options[:parameters], @headers)
		end
	end
end

# get cookies as hash
class Net::HTTPResponse
  def cookies
    cookies = {}
    ignored_cookie_names = %w{expires domain path secure httponly}
    self['set-cookie'].split(/[;,]/).each {|it|
      next unless it.include? '='
      eq = it.index('=')
      key = it[0...eq].strip
      value = it[eq.succ..-1]
      next if ignored_cookie_names.include? key.downcase
      cookies[key] = value
    }
    cookies
  end
end

# for ftp response
class Net::FTP
  def response=(response)
    @_response = response
  end

  def response
    @_response
  end
end

# exception
class NoHttpMethodException < Exception; end

# for command line
if __FILE__.eql? $0
	method, url, params = ARGV
  exit unless method
	source_method = method
	method = method.split('_')[0] if method.include? '_'

	# fix path of the url
	url = "http://#{url}" unless url =~ /^(http:\/\/)/i

	params = if params
    "{:url => '#{url}', :parameters => '" + params + "'}"
  else
    "'#{url}'"
  end

	if HttpRequest.http_methods.include?(method) && url
		http = eval("HttpRequest.#{method}(#{params})")
		case source_method
		when /_only_header$/
			http.each{|k,v| puts "#{k}: #{v}"}
		when /_with_header$/
			http.each{|k,v| puts "#{k}: #{v}"}
			print http.body unless http.body.to_s.empty?
		else
			print http.body unless http.body.to_s.empty?
		end
	end

end
