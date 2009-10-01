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
