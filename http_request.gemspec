require 'rubygems'  
SPEC=Gem::Specification.new do |s|  
	s.homepage = 'http://github.com/xianhuazhou'
	s.rubyforge_project = "http_request.rb"
	s.name = 'http_request.rb'
	s.version = '1.1.13'
	s.author = 'xianhua.zhou'  
	s.email = 'xianhua.zhou@gmail.com'
	s.platform = Gem::Platform::RUBY  
	s.summary = "http_request.rb is a small, lightweight, powerful HttpRequest class based on the 'net/http' and 'net/ftp' libraries"
	s.files = %w(Changelog README.rdoc Gemfile Rakefile lib/http_request.rb spec/test_http_request.rb spec/web_server.rb)
	s.require_path = 'lib'
	s.has_rdoc = true
end
