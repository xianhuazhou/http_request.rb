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
		hr.get(URL + '/get?lang=Ruby&version=1.9').body.should.equal({
			'lang' => 'Ruby', 'version' => '1.9'
		}.inspect)
	end

end
