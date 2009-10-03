require 'test/spec'
require File.join(File.dirname(__FILE__), '..', 'lib/http_request.rb')

URL = 'http://localhost:9527'
hr = HttpRequest

context "some basic http requests" do

	specify "get the first page" do
		hr.get(URL) do |http|
			http.body.should.equal 'It Works!'
			http['content-type'].should.equal 'text/html'
		end
		hr.get(URL + '/').body.should.equal 'It Works!'
	end

	specify "post or get method" do
		hr.get(URL + "/method/post").body.should.equal 'No'
		hr.post(URL + "/method/post").body.should.equal 'Yes'

		hr.get(URL + "/method/get").body.should.equal 'Yes'
		hr.post(URL + "/method/get").body.should.equal 'No'
	end

	specify "available http methods" do
		url = URL + '/get-method-name'
		hr.get(url).body.should.equal 'GET'
		hr.post(url).body.should.equal 'POST'
		hr.put(url).body.should.equal 'PUT'
		hr.delete(url).body.should.equal 'DELETE'
		hr.trace(url).body.should.equal 'TRACE'
		hr.lock(url).body.should.equal 'LOCK'
		hr.unlock(url).body.should.equal 'UNLOCK'
		hr.move(url).body.should.equal 'MOVE'
		hr.copy(url).body.should.equal 'COPY'
		hr.propfind(url).body.should.equal 'PROPFIND'
		hr.proppatch(url).body.should.equal 'PROPPATCH'
		hr.mkcol(url).body.should.equal 'MKCOL'

		hr.options(url).body.should.equal nil 
		hr.options(url)['content-length'].should.equal 'options'.size.to_s

		hr.head(url).body.should.equal nil
		hr.head(url)['content-length'].should.equal 'head'.size.to_s
	end

end

context "some basic requests with parameter" do

	specify "get method" do
		hr.get(URL + '/get').body.should.equal({}.inspect)
		hr.get(URL + '/get?&').body.should.equal({}.inspect)
		hr.get(URL + '/get?&#').body.should.equal({}.inspect)
		hr.get(URL + '/get?abc=').body.should.equal({'abc' => ''}.inspect)

		hr.get(URL + '/get?lang=Ruby&version=1.9').body.should.equal({
			'lang' => 'Ruby', 'version' => '1.9'
		}.inspect)

		hr.get(:url => URL + '/get', :parameters => 'lang=Ruby&version=1.9').body.should.equal({
			'lang' => 'Ruby', 'version' => '1.9'
		}.inspect)

		hr.get(:url => URL + '/get', :parameters => {:lang => 'Ruby', :version => 1.9}).body.should.equal({
			'lang' => 'Ruby', 'version' => '1.9'
		}.inspect)

		hr.get(:url => URL + '/get?lang=Ruby', :parameters => {:version => 1.9}).body.should.equal({
			'lang' => 'Ruby', 'version' => '1.9'
		}.inspect)

		hr.get(:url => URL + '/get', :parameters => {'lang' => 'Ruby', 'version' => '1.9'}).body.should.equal({
			'lang' => 'Ruby', 'version' => '1.9'
		}.inspect)

		hr.get(URL + '/get?ids[]=1&ids[]=2').body.should.equal({
      'ids' => ['1', '2']
		}.inspect)

		hr.get(:url => URL + '/get', :parameters => 'ids[]=1&ids[]=2').body.should.equal({
      'ids' => ['1', '2']
		}.inspect)

		hr.get(URL + '/get?ids[a]=1&ids[b]=2').body.should.equal({
      'ids' => {'a' => '1', 'b' => '2'}
		}.inspect)

		hr.get(:url => URL + '/get', :parameters => 'ids[a]=1&ids[b]=2').body.should.equal({
      'ids' => {'a' => '1', 'b' => '2'}
		}.inspect)

		hr.get(:url => URL + '/get', :parameters => {'ids[a]' => 1, 'ids[b]' => 2}).body.should.equal({
      'ids' => {'a' => '1', 'b' => '2'}
		}.inspect)
	end

	specify "post method" do
		hr.post(URL + '/get').body.should.equal({}.inspect)
		hr.post(URL + '/get?&').body.should.equal({}.inspect)
		hr.post(URL + '/get?&#').body.should.equal({}.inspect)
		hr.post(URL + '/get?abc=').body.should.equal({'abc' => ''}.inspect)

		hr.post(URL + '/get?lang=Ruby&version=1.9').body.should.equal({
			'lang' => 'Ruby', 'version' => '1.9'
		}.inspect)

		hr.post(:url => URL + '/get', :parameters => 'lang=Ruby&version=1.9').body.should.equal({
			'lang' => 'Ruby', 'version' => '1.9'
		}.inspect)

		hr.post(:url => URL + '/get', :parameters => {:lang => 'Ruby', :version => 1.9}).body.should.equal({
			'lang' => 'Ruby', 'version' => '1.9'
		}.inspect)

		hr.post(:url => URL + '/get', :parameters => {'lang' => 'Ruby', 'version' => '1.9'}).body.should.equal({
			'lang' => 'Ruby', 'version' => '1.9'
		}.inspect)

		hr.post(URL + '/get?ids[]=1&ids[]=2').body.should.equal({
      'ids' => ['1', '2']
		}.inspect)

		hr.post(:url => URL + '/get', :parameters => 'ids[]=1&ids[]=2').body.should.equal({
      'ids' => ['1', '2']
		}.inspect)

		hr.post(URL + '/get?ids[a]=1&ids[b]=2').body.should.equal({
      'ids' => {'a' => '1', 'b' => '2'}
		}.inspect)

		hr.post(:url => URL + '/get', :parameters => 'ids[a]=1&ids[b]=2').body.should.equal({
      'ids' => {'a' => '1', 'b' => '2'}
		}.inspect)

		hr.post(:url => URL + '/get', :parameters => {'ids[a]' => 1, 'ids[b]' => 2}).body.should.equal({
      'ids' => {'a' => '1', 'b' => '2'}
		}.inspect)
	end

end

context "http auth" do
	specify "Basic Auth" do
		hr.get("http://zhou:password@localhost:9527/auth/basic").body.should.equal "success!"
		hr.get("http://localhost:9527/auth/basic").body.should.equal ""

		hr.get(
			:url  => "http://zhou:password@localhost:9527/auth/basic",
			:auth => :basic
		).body.should.equal "success!"

		hr.get(
			:url  => "http://localhost:9527/auth/basic",
			:auth_username => 'zhou',
			:auth_password => 'password',
			:auth => :basic
		).body.should.equal "success!"

		hr.get(
			:url  => "http://localhost:9527/auth/basic",
			:auth => {
				 :password => 'password',
				 :username => 'zhou',
			   :type => :basic
		   }
		).body.should.equal "success!"

		hr.get(
			:url  => "http://localhost:9527/auth/basic",
			:auth => {
				 :password => 'password',
				 :username => 'zhou'
		   }
		).body.should.equal "success!"
	end

	specify "Digest Auth" do
		hr.get(
			:url  => "http://zhou:password@localhost:9527/auth/digest",
			:auth => :digest
		).body.should.equal "success!"

		hr.get(
			:url  => "http://localhost:9527/auth/digest",
			:auth_username => 'zhou',
			:auth_password => 'password',
			:auth => :digest
		).body.should.equal "success!"

		hr.get(
			:url  => "http://localhost:9527/auth/digest",
			:auth => {
				 :password => 'password',
				 :username => 'zhou',
			   :type => :digest
		   }
		).body.should.equal "success!"
	end

end

context 'Session && Cookie' do
	specify "Session" do
		h = hr.get(URL + "/session")
		h.body.should.equal "1"

		h = hr.get(:url => URL + "/session", :cookies => h.cookies)
		h.body.should.equal "2"

		h = hr.get(:url => URL + "/session", :cookies => h.cookies)
		h.body.should.equal "3"

		h1 = hr.get(URL + "/session")
		h1.body.should.equal "1"

		h1 = hr.get(:url => URL + "/session", :cookies => h1.cookies)
		h1.body.should.equal "2"

		h = hr.get(URL + "/session/1")
		h.body.should.equal "/session/1:/session/2"

		h = hr.get(:url => URL + "/session/1", :redirect => false)
		h.code_3xx?.should.equal true
	end

	specify "Cookie" do
		h = hr.get(URL + "/cookie")
		h.cookies['name'].should.equal 'zhou'
	end
end

context 'upload file' do
	specify 'upload file' do
		files = [{:file_name => 'hi.txt', :field_name => 'file', :file_content => 'hi'}]
		h = hr.post(:url => URL + '/upload_file', :files => files)
		h.body.should.equal 'hi.txt - hi'
	end

	specify 'upload file with parameters' do
		files = [{:file_name => 'hi.txt', :field_name => 'file', :file_content => 'hi'}]
		h = hr.post(:url => URL + '/upload_file', :files => files, :parameters => {:name => 'Ruby'})
		h.body.should.equal 'hi.txt - hi' + {'name' => 'Ruby'}.inspect
	end

	specify 'upload file with parameters and query string' do
		files = [{:file_name => 'hi.txt', :field_name => 'file', :file_content => 'hi'}]
		h = hr.post(:url => URL + '/upload_file?version=1.9', :files => files, :parameters => {:name => 'Ruby'})
		h.body.should.equal 'hi.txt - hi' + {'name' => 'Ruby', 'version' => '1.9'}.inspect
	end

	specify 'upload 2 files' do
		files = [
			{:file_name => 'hi.txt', :field_name => 'file', :file_content => 'hi'},
			{:file_name => 'ih.txt', :field_name => 'elif', :file_content => 'ih'}
		]
		h = hr.post(:url => URL + '/upload_file2', :files => files)
		h.body.should.equal 'hi.txt - hi, ih.txt - ih' 
	end
end
