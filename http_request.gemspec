require 'rubygems'  
SPEC=Gem::Specification.new do |s|  
	s.homepage = 'http://my.cnzxh.net'
	s.rubyforge_project = "http_request.rb"
	s.name = 'http_request.rb'
	s.version = '1.0.6'  
	s.author = 'xianhua.zhou'  
	s.email = 'xianhua.zhou@gmail.com'
	s.platform = Gem::Platform::RUBY  
	s.summary = "http_request.rb is a small, lightweight, powerful HttpRequest class based on the 'net/http' and 'net/ftp' libraries"
	s.files = %w(Changelog README.rdoc lib/http_request.rb)
	s.require_path = 'lib'
	s.has_rdoc = true
end
