#!/usr/local/bin/ruby
#
# == Description
#
#   this is a small, lightweight, powerful HttpRequest class based on 'net/http' library, it's easy to use to send http request and get response, also can use it as a shell script in command line.
#
#
# == Author
#
#   xianhua.zhou<xianhua.zhou@gmail.com>
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
						'User-Agent' => 'Mozilla/5.0 (X11; U; Linux i686; zh-CN; rv:1.8.0.6) Gecko/20060728 Firefox/1.5.0.6',
						'Connection' => 'keep-alive',
				}

        # Basic Authenication
        @headers['Authorization'] = "Basic " + [@uri.userinfo].pack('m').delete!("\r\n") if @uri.userinfo

        # headers
        @options[:headers].each {|k, v| @headers[k] = v} if @options[:headers].class.to_s.eql?('Hash')

        @redirect_times = 0 if @options[:redirect]
	end

	def request(method, opt)
		init_args(method, opt)
		@options[:method] = method

		if @options[:parameters].is_a? Hash
            @options[:parameters] = @options[:parameters].collect{|k, v| 
                CGI.escape(k.to_s) + '=' + CGI.escape(v.to_s)
            }.join('&')
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

		# get data by post or get method.
		response = send_request http

		return response unless @options[:redirect]

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
			response
		end
	end

	def self.method_missing(method_name, args)
		method_name = method_name.to_s.downcase
		raise NoHttpMethodException, "No such http method can be called: #{method_name}" unless self.http_methods.include?(method_name)
		self.instance.request(method_name, args)
	end

	private
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

class NoHttpMethodException < Exception; end

# for command line
if __FILE__.eql? $0
	method, url, params = ARGV
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
