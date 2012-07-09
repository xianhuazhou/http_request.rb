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
#   v1.1.12
#
#   Last Change: 21 May, 2012
#
# == Author
#
#   xianhua.zhou<xianhua.zhou@gmail.com>
#
#
require 'cgi'
require 'net/http'
require 'net/https'
require 'net/ftp'
require 'singleton'
require 'digest/md5'
require 'stringio'

class HttpRequest
  include Singleton
  class << self
    # version
    VERSION = '1.1.12'.freeze
    def version;VERSION;end

    # available http methods
    def http_methods
      %w{get head post put proppatch lock unlock options propfind delete move copy mkcol trace}
    end

    # return data with or without block
    def data(response, &block)
      response.url = @@__url if defined? @@__url
      block_given? ? block.call(response) : response
    end

    # update cookies
    def update_cookies(response)
      return unless response.header['set-cookie']
      response.get_fields('set-cookie').each {|k|
        k, v = k.split(';')[0].split('=')
        @@__cookies[k] = v
      }
    end

    # return cookies
    def cookies
      @@__cookies
    end

    # check the http resource whether or not available
    def available?(url, timeout = 5)
      timeout(timeout) {
        u = URI(url)
        s = TCPSocket.new(u.host, u.port)
        s.close
      }
      return true
    rescue Exception => e
      return false
    end 

    private
    def call_request_method(method_name, *options, &block)
      options = if options.size.eql? 2
                  options.last.merge({:url => options.first})
                else
                  options.first
                end

      # we need to retrieve the cookies from last http response before reset cookies if it's a Net::HTTPResponse
      options[:cookies] = options[:cookies].cookies if options.is_a?(Hash) and options[:cookies].is_a?(Net::HTTPResponse)

      # reset
      @@__cookies = {}
      @@redirect_times = 0
      self.instance.request(method_name, options, &block)
    end

  end

  # define some http methods
  self.http_methods.each do |method_name|
    instance_eval %Q{ 
      def #{method_name}(*options, &block)
        call_request_method('#{method_name}', *options, &block)
      end
    }
  end

  def data(response, &block)
    self.class.data(response, &block)
  end

  # send request by some given parameters
  def request(method, options, &block)

    # parse the @options
    parse_options(method, options)

    # parse and merge for the options[:parameters]
    parse_parameters

    # send http request and get the response
    response = send_request_and_get_response

    return data(response, &block) unless @options[:redirect]

    # redirect?
    process_redirection response, &block
  end 

  # for ftp, no plan to add new features to this method except bug fixing
  def self.ftp(method, options, &block)
    options = {:url => options} if options.is_a? String
    options = {:close => true}.merge(options)
    @@__url = options[:url] = "ftp://#{options[:url]}" unless options[:url] =~ /^ftp:\/\//
    uri = URI(options[:url])
    guest_name, guest_pass = 'anonymous', "guest@#{uri.host}"
    unless options[:username]
      options[:username], options[:password] = 
        uri.userinfo ? uri.userinfo.split(':') : [guest_name, guest_pass]
    end
    options[:username] = guest_name unless options[:username]
    options[:password] = guest_pass if options[:password].nil?
    ftp = Net::FTP.open(uri.host, options[:username], options[:password])
    return data(ftp, &block) unless method
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
    if options[:close] and not block_given?
      ftp.close
      stat
    else
      ftp.response = stat unless ftp.response
      data(ftp, &block)
    end
  end

  private

  def md5(string)
    Digest::MD5.hexdigest string
  end

  # get params for the Digest auth
  # see: http://www.rooftopsolutions.nl/article/223
  def get_params_for_digest
    return '' unless @options[:auth_username] and @options[:auth_password]
    user, passwd = @options[:auth_username], @options[:auth_password]
    hr = self.class.send @options[:method], 
      @uri.userinfo ? 
      @@__url.sub(/:\/\/(.+?)@/, '://') : 
      @@__url

    params = HttpRequestParams.parse hr['WWW-Authenticate'].split(' ', 2).last
    method = @options[:method].upcase
    cnonce = md5(rand.to_s + Time.new.to_s)
    nc = "00000001"

    data = []
    data << md5("#{user}:#{params['realm']}:#{passwd}") \
    << params['nonce'] \
      << ('%08x' % nc) \
      << cnonce \
      << params['qop'] \
      << md5("#{method}:#{@uri.path}")

    params = params.update({
      :username => user,
      :nc => nc,
      :cnonce => cnonce,
      :uri => @uri.path,
      :method => method,
      :response => md5(data.join(":"))
    })

    headers = []
    params.each {|k, v| headers << "#{k}=\"#{v}\"" }
    headers.join(", ")
  rescue
    ''
  end

  # for the Http Auth if need
  def parse_http_auth
    if @options[:auth] or
      @uri.userinfo or
      (@options[:auth_username] and @options[:auth_password])

      if @options[:auth].is_a? Hash
        @options[:auth_username] = @options[:auth][:username]
        @options[:auth_password] = @options[:auth][:password]
        @options[:auth] = @options[:auth][:type]
      elsif @uri.userinfo and (!@options[:auth_username] or !@options[:auth_password])
        @options[:auth_username], @options[:auth_password] = @uri.userinfo.split(/:/, 2)
      end

      if @options[:auth_username] and @options[:auth_password]
        # Digest Auth
        if @options[:auth].to_s == 'digest'
          digest = get_params_for_digest
          @headers['Authorization'] = "Digest " + digest unless digest.empty?
        else
          # Basic Auth
          @headers['Authorization'] = "Basic " + 
            ["#{@options[:auth_username]}:#{@options[:auth_password]}"].pack('m').delete!("\r\n")
        end
      end

    end
  end

  # initialize for the http request
  def parse_options(method, options)
    options = {:url => options.to_s} if [String, Array].include? options.class
    @options = {
      :ssl_port        => 443,
      :redirect_limits => 5,
      :redirect        => true,
      :url             => nil,
      :ajax            => false,
      :xhr             => false,
      :method          => method
    }
    @options.merge!(options)
    @@__url = @options[:url]
    @uri = URI(@options[:url])
    @uri.path = '/' if @uri.path.empty?
    @headers = {
      'Host'            => @uri.host,
      'Referer'         => @options[:url],
      'User-Agent'      => 'HttpRequest.rb ' + self.class.version
    }

    # support gzip
    begin; require 'zlib'; rescue LoadError; end
    @headers['Accept-Encoding'] = 'gzip,deflate' if defined? ::Zlib

    # ajax calls?
    @headers['X-Requested-With'] = 'XMLHttpRequest' if @options[:ajax] or @options[:xhr]

    # Http Authentication
    parse_http_auth

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
  end

  # parse parameters for the options[:parameters] and @uri.query
  def parse_parameters
    if @options[:parameters].is_a?(Hash)
      @options[:parameters] = @options[:parameters].collect{|k, v| 
        "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"
      }.join('&')
    end
    @options[:parameters] = '' if @options[:parameters].nil?
    if not @uri.query.to_s.empty? 
      @options[:parameters] << (@options[:parameters].empty? ? @uri.query : "&#{@uri.query}")
    end

    # for uploading files
    build_multipart	if @options[:files] and 'post'.eql?(@options[:method])
  end

  # for uploading files
  def build_multipart
    boundary = md5(rand.to_s).to_s[0..5]
    @headers['Content-type'] = "multipart/form-data, boundary=#{boundary}"
    multipart = []
    if @options[:parameters].is_a?(String)
      @options[:parameters] = CGI.parse(@options[:parameters])
      if @options[:parameters].is_a? Hash
        @options[:parameters].each {|k, v| 
          multipart << "--#{boundary}" 
          multipart << "Content-disposition: form-data; name=\"#{k}\"" 
          multipart << "\r\n#{v.first}"
        }
      end
    end
    @options[:files] = [@options[:files]] if @options[:files].is_a?(Hash)
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
    multipart.each_with_index do |val, key|
      multipart[key] = val.force_encoding('UTF-8')
    end
    multipart = multipart.join("\r\n")
    @headers['Content-length'] = "#{multipart.size}"
    @options[:parameters] = multipart
  end

  # send request and get the response by some options
  def send_request_and_get_response
    # for proxy
    http = if @options[:proxy_addr]
             if @options[:proxy_user] and @options[:proxy_pass]
               Net::HTTP::Proxy(
                 @options[:proxy_addr], 
                 @options[:proxy_port], 
                 @options[:proxy_user], 
                 @options[:proxy_pass]
               ).new(@u.host, @u.port)
             else
               Net::HTTP::Proxy(
                 @options[:proxy_addr], 
                 @options[:proxy_port]
               ).new(@uri.host, @uri.port)
             end
           else
             Net::HTTP.new(@uri.host, @uri.port)
           end

    # ssl support
    http.use_ssl = true if @uri.scheme =~ /^https$/i

    # sending request and get response 
    send_request http
  end

  # send http request
  def send_request(http)
    # xml data?
    if @options[:parameters].to_s[0..4].eql?('<?xml') and @options[:method].eql? 'post'
      @headers['Content-Type'] = 'application/xml'
      @headers['Content-Length'] = @options[:parameters].size.to_s
      @headers['Content-MD5'] = md5(@options[:parameters]).to_s
    end

    # GO !!
    if @options[:method] =~ /^(get|head|options|delete|move|copy|trace|)$/
      @options[:parameters] = "?#{@options[:parameters]}" if @options[:parameters]
      path = if @options[:parameters] =~ /^\?+$/ 
               @uri.path 
             else 
               @uri.path + @options[:parameters]
             end
    h = http.method(@options[:method]).call(path, @headers)
    else
      h = http.method(@options[:method]).call("#{@uri.path}?#{@uri.query}", @options[:parameters], @headers)
    end

    self.class.update_cookies h
    h
  end

  # process the redirection if need
  def process_redirection(response, &block)
    case response
    when Net::HTTPRedirection
      url = "#{@uri.scheme}://#{@uri.host}#{':' + @uri.port.to_s if @uri.port != 80}"
      last_url = @options[:url]
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
      return data(response, &block) if @@redirect_times > 2 and @options[:url].eql? last_url
      @@redirect_times += 1 
      raise 'too many redirects...' if @@redirect_times > @options[:redirect_limits]
      if @options[:cookies].nil?
        @options[:cookies] = self.class.cookies
      else
        @options[:cookies] = @options[:cookies].update self.class.cookies
      end
      @options.delete :parameters
      @options.delete :method
      request('get', @options, &block)
    else
      data(response, &block)
    end
  end

end

module Net
  class HTTPResponse

    attr_accessor :url

    # get cookies as a hash
    def cookies
      HttpRequest.cookies
    end

    # for gzipped body
    def body
      bd = read_body()
      return bd unless bd
      if (self['content-encoding'] == 'gzip') and defined?(::Zlib)
        ::Zlib::GzipReader.new(StringIO.new(bd)).read
      else
        bd
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
      when /^(code|status)_([0-9])xx\?$/
        not CODE_CLASS_TO_OBJ[$2].nil? and is_a? CODE_CLASS_TO_OBJ[$2]
      when /^(code|status)_([0-9]+)\?$/
        not CODE_TO_OBJ[$2].nil? and is_a? CODE_TO_OBJ[$2]
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

# from Rack, parsing parameters for the Digest auth
class HttpRequestParams < Hash
  def self.parse(str)
    split_header_value(str).inject(new) do |header, param|
      k, v = param.split('=', 2)
      header[k] = dequote(v)
      header
    end
  end

  def self.dequote(str) # From WEBrick::HTTPUtils
    ret = (/\A"(.*)"\Z/ =~ str) ? $1 : str.dup
    ret.gsub!(/\\(.)/, "\\1")
    ret
  end

  def self.split_header_value(str)
    str.scan( /(\w+\=(?:"[^\"]+"|[^,]+))/n ).collect{ |v| v[0] }
  end

  def initialize
    super

    yield self if block_given?
  end

  def [](k)
    super k.to_s
  end

  def []=(k, v)
    super k.to_s, v.to_s
  end

  UNQUOTED = ['qop', 'nc', 'stale']

  def to_s
    inject([]) do |parts, (k, v)|
      parts << "#{k}=" + (UNQUOTED.include?(k) ? v.to_s : quote(v))
    parts
    end.join(', ')
  end

  def quote(str) # From WEBrick::HTTPUtils
    '"' << str.gsub(/[\\\"]/o, "\\\1") << '"'
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
