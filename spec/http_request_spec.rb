require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'lib', 'http_request.rb')

URL = 'http://localhost:9527'
hr = HttpRequest

describe HttpRequest do

  before :all do 
    Thread.new do |t|
      web_server = File.join(File.expand_path(File.dirname(__FILE__)), 'web_server.rb')
      @process_id = spawn "ruby #{web_server}", :in => "/dev/null", :out => "/dev/null"
      sleep 2
    end.join
  end

  after :all do
    Process.kill 'KILL', @process_id
    Process.wait
  end

  context "some basic http requests" do

    it "can get the first page" do
      hr.get(URL) do |http|
        http.body.should == 'It Works!'
        http['content-type'].should == 'text/html'
      end
      hr.get(URL + '/').body.should == 'It Works!'
    end

    it "has post or get method" do
      hr.get(URL + "/method/post").body.should == 'No'
      hr.post(URL + "/method/post").body.should == 'Yes'

      hr.get(URL + "/method/get").body.should == 'Yes'
      hr.post(URL + "/method/get").body.should == 'No'
    end

    it "can send AJAX requests" do
      hr.get(:url => URL + "/ajax").body.should == 'N'
      hr.get(:url => URL + "/ajax", :xhr => true).body.should == 'Y'
      hr.get(:url => URL + "/ajax", :ajax => true).body.should == 'Y'

      hr.get(URL + "/ajax", :xhr => true).body.should == 'Y'
      hr.get(URL + "/ajax", :ajax => true).body.should == 'Y'
    end

    it "supports the following methods" do
      url = URL + '/get-method-name'
      hr.get(url).body.should == 'GET'
      hr.post(url).body.should == 'POST'
      hr.put(url).body.should == 'PUT'
      hr.delete(url).body.should == 'DELETE'
      hr.trace(url).body.should == 'TRACE'
      hr.lock(url).body.should == 'LOCK'
      hr.unlock(url).body.should == 'UNLOCK'
      hr.move(url).body.should == 'MOVE'
      hr.copy(url).body.should == 'COPY'
      hr.propfind(url).body.should == 'PROPFIND'
      hr.proppatch(url).body.should == 'PROPPATCH'
      hr.mkcol(url).body.should == 'MKCOL'
      hr.options(url).body.should == nil 
      hr.head(url).body.should == nil
    end

  end

  context "some basic requests with parameter" do

    it "should work with the get method" do
      hr.get(URL + '/get').body.should ==({}.inspect)
      hr.get(URL + '/get?&').body.should ==({}.inspect)
      hr.get(URL + '/get?&#').body.should ==({}.inspect)
      hr.get(URL + '/get?abc=').body.should ==({'abc' => ''}.inspect)

      hr.get(URL + '/get?lang=Ruby&version=1.9').body.should include('"lang"=>"Ruby"')
      hr.get(URL + '/get?lang=Ruby&version=1.9').body.should include('"version"=>"1.9"')

      hr.get(:url => URL + '/get', :parameters => 'lang=Ruby&version=1.9').body.should include('"lang"=>"Ruby"')
      hr.get(:url => URL + '/get', :parameters => 'lang=Ruby&version=1.9').body.should include('"version"=>"1.9"')

      hr.get(:url => URL + '/get', :parameters => {:lang => 'Ruby', :version => '1.9'}).body.should include('"lang"=>"Ruby"')
      hr.get(:url => URL + '/get', :parameters => {:lang => 'Ruby', :version => '1.9'}).body.should include('"version"=>"1.9"')

      hr.get(:url => URL + '/get?lang=Ruby', :parameters => {:version => '1.9'}).body.should include('"lang"=>"Ruby"')
      hr.get(:url => URL + '/get?lang=Ruby', :parameters => {:version => '1.9'}).body.should include('"version"=>"1.9"')

      hr.get(:url => URL + '/get', :parameters => {'lang' => 'Ruby', 'version' => '1.9'}).body.should include('"lang"=>"Ruby"')
      hr.get(:url => URL + '/get', :parameters => {'lang' => 'Ruby', 'version' => '1.9'}).body.should include('"version"=>"1.9"')

      hr.get(URL + '/get', :parameters => {'lang' => 'Ruby', 'version' => '1.9'}).body.should include('"lang"=>"Ruby"')
      hr.get(URL + '/get', :parameters => {'lang' => 'Ruby', 'version' => '1.9'}).body.should include('"version"=>"1.9"')

      hr.get(URL + '/get?ids[]=1&ids[]=2').body.should ==({
        'ids' => ['1', '2']
      }.inspect)

      hr.get(:url => URL + '/get', :parameters => 'ids[]=1&ids[]=2').body.should ==({
        'ids' => ['1', '2']
      }.inspect)

      hr.get(URL + '/get?ids[a]=1&ids[b]=2').body.should ==({
        'ids' => {'a' => '1', 'b' => '2'}
      }.inspect)

      hr.get(:url => URL + '/get', :parameters => 'ids[a]=1&ids[b]=2').body.should ==({
        'ids' => {'a' => '1', 'b' => '2'}
      }.inspect)

      hr.get(:url => URL + '/get', :parameters => {'ids[a]' => 1, 'ids[b]' => 2}).body.should include('"ids"=>{')
      hr.get(:url => URL + '/get', :parameters => {'ids[a]' => 1, 'ids[b]' => 2}).body.should include('"a"=>"1"')
      hr.get(:url => URL + '/get', :parameters => {'ids[a]' => 1, 'ids[b]' => 2}).body.should include('"b"=>"2"')

      hr.get(:url => URL + '/get', :parameters => {:ids => ['1', '2']}).body.should == {
          'ids' => ['1', '2']
      }.inspect
    end

    it "should work with the post method" do
      hr.post(URL + '/get').body.should ==({}.inspect)
      hr.post(URL + '/get?&').body.should ==({}.inspect)
      hr.post(URL + '/get?&#').body.should ==({}.inspect)
      hr.post(URL + '/get?abc=').body.should ==({'abc' => ''}.inspect)

      hr.post(URL + '/get?lang=Ruby&version=1.9').body.should include('"lang"=>"Ruby"')
      hr.post(URL + '/get?lang=Ruby&version=1.9').body.should include('"version"=>"1.9"')

      hr.post(:url => URL + '/get', :parameters => 'lang=Ruby&version=1.9').body.should include('"lang"=>"Ruby"')
      hr.post(:url => URL + '/get', :parameters => 'lang=Ruby&version=1.9').body.should include('"version"=>"1.9"')

      hr.post(:url => URL + '/get', :parameters => {:lang => 'Ruby', :version => '1.9'}).body.should include('"lang"=>"Ruby"')
      hr.post(:url => URL + '/get', :parameters => {:lang => 'Ruby', :version => '1.9'}).body.should include('"version"=>"1.9"')

      hr.post(:url => URL + '/get?lang=Ruby', :parameters => {:version => '1.9'}).body.should include('"lang"=>"Ruby"')
      hr.post(:url => URL + '/get?lang=Ruby', :parameters => {:version => '1.9'}).body.should include('"version"=>"1.9"')

      hr.post(:url => URL + '/get', :parameters => {'lang' => 'Ruby', 'version' => '1.9'}).body.should include('"lang"=>"Ruby"')
      hr.post(:url => URL + '/get', :parameters => {'lang' => 'Ruby', 'version' => '1.9'}).body.should include('"version"=>"1.9"')

      hr.post(URL + '/get', :parameters => {'lang' => 'Ruby', 'version' => '1.9'}).body.should include('"lang"=>"Ruby"')
      hr.post(URL + '/get', :parameters => {'lang' => 'Ruby', 'version' => '1.9'}).body.should include('"version"=>"1.9"')

      hr.post(URL + '/get?ids[]=1&ids[]=2').body.should ==({
        'ids' => ['1', '2']
      }.inspect)

      hr.post(:url => URL + '/get', :parameters => 'ids[]=1&ids[]=2').body.should ==({
        'ids' => ['1', '2']
      }.inspect)

      hr.post(URL + '/get?ids[a]=1&ids[b]=2').body.should ==({
        'ids' => {'a' => '1', 'b' => '2'}
      }.inspect)

      hr.post(:url => URL + '/get', :parameters => 'ids[a]=1&ids[b]=2').body.should ==({
        'ids' => {'a' => '1', 'b' => '2'}
      }.inspect)

      hr.post(:url => URL + '/get', :parameters => {'ids[a]' => 1, 'ids[b]' => 2}).body.should include('"ids"=>{')
      hr.post(:url => URL + '/get', :parameters => {'ids[a]' => 1, 'ids[b]' => 2}).body.should include('"a"=>"1"')
      hr.post(:url => URL + '/get', :parameters => {'ids[a]' => 1, 'ids[b]' => 2}).body.should include('"b"=>"2"')

      hr.post(:url => URL + '/get', :parameters => {:ids => ['1','2']}).body.should == {
          'ids' => ['1', '2']
      }.inspect
    end

  end

  context "http auth" do
    it "supports the Basic Auth" do
      hr.get("http://zhou:password@localhost:9527/auth/basic").body.should == "success!"
      hr.get("http://localhost:9527/auth/basic").body.should == ""

      hr.get(
        :url  => "http://zhou:password@localhost:9527/auth/basic",
        :auth => :basic
      ).body.should == "success!"

      hr.get(
        :url  => "http://localhost:9527/auth/basic",
        :auth_username => 'zhou',
        :auth_password => 'password',
        :auth => :basic
      ).body.should == "success!"

      hr.get(
        :url  => "http://localhost:9527/auth/basic",
        :auth => {
        :password => 'password',
        :username => 'zhou',
        :type => :basic
      }
      ).body.should == "success!"

      hr.get(
        :url  => "http://localhost:9527/auth/basic",
        :auth => {
        :password => 'password',
        :username => 'zhou'
      }
      ).body.should == "success!"
    end

    it "supports the Digest Auth" do
      hr.get(
        :url  => "http://zhou:password@localhost:9527/auth/digest",
        :auth => :digest
      ).body.should == "success!"

      hr.get(
        :url  => "http://localhost:9527/auth/digest",
        :auth_username => 'zhou',
        :auth_password => 'password',
        :auth => :digest
      ).body.should == "success!"

      hr.get(
        :url  => "http://localhost:9527/auth/digest",
        :auth => {
        :password => 'password',
        :username => 'zhou',
        :type => :digest
      }
      ).body.should == "success!"
    end

  end

  context 'Session and Cookie' do
    it "can work with session" do
      h = hr.get(URL + "/session")
      h.body.should == "1"

      h = hr.get(:url => URL + "/session", :cookies => h.cookies)
      h.body.should == "2"

      h = hr.get(:url => URL + "/session", :cookies => h.cookies)
      h.body.should == "3"

      h1 = hr.get(URL + "/session")
      h1.body.should == "1"

      h1 = hr.get(:url => URL + "/session", :cookies => h1.cookies)
      h1.body.should == "2"

      h2 = hr.get(URL + "/session")
      h2.body.should == "1"

      h2 = hr.get(:url => URL + "/session", :cookies => h2)
      h2.body.should == "2"

      h = hr.get(URL + "/session/1")
      h.body.should == "/session/1:/session/2"

      h = hr.get(:url => URL + "/session/1", :redirect => false)
      h.code_3xx?.should == true
    end

    it "can work with cookies" do
      h = hr.get(URL + "/cookie")
      h.cookies['name'].should == 'zhou'
    end
  end

  context 'upload file' do
    it 'can upload 1 file' do
      files = [{:file_name => 'hi.txt', :field_name => 'file', :file_content => 'hi'}]
      h = hr.post(:url => URL + '/upload_file', :files => files)
      h.body.should == 'hi.txt - hi'
    end

    it 'can upload 1 file with parameters' do
      files = [{:file_name => 'hi.txt', :field_name => 'file', :file_content => 'hi'}]
      h = hr.post(:url => URL + '/upload_file', :files => files, :parameters => {:name => 'Ruby'})
      h.body.should == 'hi.txt - hi' + {'name' => 'Ruby'}.inspect
    end

    it 'can upload 1 file with parameters and query string' do
      files = [{:file_name => 'hi.txt', :field_name => 'file', :file_content => 'hi'}]
      h = hr.post(:url => URL + '/upload_file?version=1.9', :files => files, :parameters => {:name => 'Ruby'})
      h.body.should include('1.9')
      h.body.should include('version')
      h.body.should include('name')
      h.body.should include('Ruby')
      h.body.should include('hi.txt - hi')
    end

    it 'can upload 2 files' do
      files = [
        {:file_name => 'hi.txt', :field_name => 'file', :file_content => 'hi'},
        {:file_name => 'ih.txt', :field_name => 'elif', :file_content => 'ih'}
      ]
      h = hr.post(:url => URL + '/upload_file2', :files => files)
      h.body.should == 'hi.txt - hi, ih.txt - ih' 
    end
  end

end
