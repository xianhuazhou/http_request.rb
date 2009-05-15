#!/usr/bin/env ruby
#
# == Description
#
#   This is a small, lightweight, powerful HttpRequest class based on the 'net/http' and 'net/ftp' libraries, 
#   it's easy to use to send http request and get response, also can use it as a shell script on command line in some cases.
#
# == Example
#
#   Please read README.rdoc
#
# == Version
# 
#   v1.0.3
#
#   Last Change: 15 May, 2009
#
# == Author
#
#   xianhua.zhou<xianhua.zhou@gmail.com>
#   homepage: http://my.cnzxh.net
#
#
require 'cgi'
require 'net/http'
require 'net/https'
require 'net/ftp'
require 'singleton'

class HttpRequest
	include Singleton

	# version
	VERSION = '1.0.3'.freeze
	def self.version;VERSION;end

	# avaiabled http methods
	def self.http_methods
		%w{get head post put proppatch lock unlock options propfind delete move copy mkcol trace}
	end

	# return data with or without block
	def self.data(response, &block)
		block_given? ? block.call(response) : response
	end

	# check the http resource whether or not available
	def self.available?(url, timeout = nil)
		timeout(timeout) {
			u = URI(url)
			s = TCPSocket.new(u.host, u.port)
			s.close
		}
		return true
	rescue
		return false
	end

	# send request by some given parameters
	def request(method, opt, &block)
		init_args(method, opt)
		@options[:method] = method

		# for upload files
		if @options[:files].is_a?(Array) && 'post'.eql?(method)
			build_multipart
		else
			if @options[:parameters].is_a? Hash
				@options[:parameters] = @options[:parameters].collect{|k, v| 
					"#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"
				}.join('&')
			end
		end

		# for proxy
		http = if @options[:proxy_addr]
						 if @options[:proxy_user] && @options[:proxy_pass]
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

		return HttpRequest.data(response, &block) unless @options[:redirect]

		# redirect?
		case response
		when Net::HTTPRedirection
			url = "#{@uri.scheme}://#{@uri.host}#{':' + @uri.port.to_s if @uri.port != 80}"
			@options[:url] = case response['location']
											 when /^https?:\/\//i
												 response['location']
											 when /^\// 
												 url + response['location']
											 when /^(\.\.\/|\.\/)/
												 paths = (File.dirname(@uri.path) + '/' + response['location']).split('/')
												 location = []
												 paths.each {|path|
													 next if path.empty? || path.eql?('.')
													 path == '..' ? location.pop : location.push(path)
												 }
												 url + '/' + location.join('/')
											 else
												 url + File.dirname(@uri.path) + '/' + response['location']
											 end
			@redirect_times = @redirect_times.succ
			raise 'too many redirects...' if @redirect_times > @options[:redirect_limits]
			request('get', @options, &block)
		else
			return HttpRequest.data(response, &block)
		end
	end

	# catch all of http requests
	def self.method_missing(method_name, args, &block)
		method_name = method_name.to_s.downcase
		raise NoHttpMethodException, "No such http method can be called: #{method_name}" unless self.http_methods.include?(method_name)
		self.instance.request(method_name, args, &block)
	end

	# for ftp
	def self.ftp(method, options, &block)
		options = {:url => options} if options.is_a? String
		options = {:close => true}.merge(options)
		options[:url] = "ftp://#{options[:url]}" unless options[:url] =~ /^ftp:\/\//
		uri = URI(options[:url])
		guest_name, guest_pass = 'anonymous', "guest@#{uri.host}"
		unless options[:username]
			options[:username], options[:password] = uri.userinfo ? uri.userinfo.split(':') : [guest_name, guest_pass]
		end
		options[:username] = guest_name unless options[:username]
		options[:password] = guest_pass if options[:password].nil?
		ftp = Net::FTP.open(uri.host, options[:username], options[:password])
		return self.data(ftp, &block) unless method
		stat = case method.to_sym
					 when :get_as_string
						 require 'tempfile'
						 tmp = Tempfile.new('http_request_ftp')
						 ftp.getbinaryfile(uri.path, tmp.path)
						 ftp.response = tmp.read
						 tmp.close
						 unless block_given?
							 ftp.close
							 return ftp.response
						 end
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
		if options[:close] && !block_given?
			ftp.close
			stat
		else
			ftp.response = stat unless ftp.response
			self.data(ftp, &block)
		end
	end

	private

	# initialize for the http request
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
			'Host'            => @uri.host,
			'Accept-Encoding' => 'gzip,deflate',
			'Referer'         => @options[:url],
			'User-Agent'      => 'HttpRequest.rb ' + VERSION
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

	# send http request
	def send_request(http)

		# merge parameters
		parameters = @options[:parameters].to_s
		@options[:parameters] = "#{@uri.query}" if @uri.query
		if parameters
			if @options[:parameters]
				@options[:parameters] << "&#{parameters}"
			else
				@options[:parameters] = "#{parameters}"
			end
		end

		# GO !!
		if @options[:method] =~ /^(get|head|options|delete|move|copy|trace|)$/
			@options[:parameters] = "?#{@options[:parameters]}" if @options[:parameters]
			http.method(@options[:method]).call("#{@uri.path}#{@options[:parameters]}", @headers)
		else
			http.method(@options[:method]).call(@uri.path, @options[:parameters], @headers)
		end

	end

end

module Net
	class HTTPResponse

		# get cookies as a hash
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

		# for gzipped body
		def body
			unless self['content-encoding'].eql? 'gzip'
				read_body()
			else
				require 'stringio'
				Zlib::GzipReader.new(StringIO.new(read_body())).read
			end
		end

		# body
		def raw_body
			read_body()
		end

		# detect the response code
		#
		# Example:
		# puts HttpRequest.get('http://www.example.com').code_200?
		# puts HttpRequest.get('http://www.example.com').code_2xx?
		# HttpRequest.get('http://www.example.com/404.html') {|http|
		#   puts "IS 4xx" if http.code_4xx?
		#   puts "IS 404" if http.code_404?
		# }
		#
		# supported methods
		# code_1xx? code_2xx? code_3xx? code_4xx? code_5xx?
		# code_100? code_101? code_200? code_201? ... code_505?
		def method_missing(method_name)
			case method_name.to_s
			when /^code_([0-9])xx\?$/
				is_a? CODE_CLASS_TO_OBJ[$1]
			when /^code_([0-9]+)\?$/
				is_a? CODE_TO_OBJ[$1]
			else
				raise NoHttpMethodException, 'Unknown method of response code!'
			end
		end

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
	url = "http://#{url}" unless url =~ /^(https?:\/\/)/i

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
