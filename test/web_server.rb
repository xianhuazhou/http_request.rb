#!/usr/bin/env ruby
require 'rubygems'
require 'rack'
include Rack

builder = Builder.new do

	map '/' do
		run lambda {|env| 
			[200, {'Content-Type' => 'text/html'}, 'It Works!']
		}
	end

	map '/get' do
		run lambda {|env|
			[200, {'Content-Type' => 'text/html'}, Request.new(env).params.inspect]
		}
	end

	map '/post' do
		run lambda {|env|
			[200, {'Content-Type' => 'text/html'}, Request.new(env).params.inspect]
		}
	end

	map '/method/post' do
		run lambda {|env|
			body = Request.new(env).post? ? 'Yes' : 'No'
			[200, {'Content-Type' => 'text/html'}, body]
		}
	end

	map '/method/get' do
		run lambda {|env|
			body = Request.new(env).get? ? 'Yes' : 'No'
			[200, {'Content-Type' => 'text/html'}, body]
		}
	end

	map '/get-method-name' do
		run lambda {|env|
			[200, {'Content-Type' => 'text/html'}, Request.new(env).request_method]
		}
	end

	map '/auth/basic' do
		auths = {:username => 'zhou', :password => 'password'}

		app = lambda {|env|
			headers = {
         'Content-Type'       => 'text/html'
			}
			[200, headers, 'success!']
		}

		app = Auth::Basic.new(app) {|user, pass| 
			auths[:username] == user and auths[:password] == pass
		}
		app.realm = 'HttpRequest'
		run app
	end

	map '/auth/digest' do
		auths = {:username => 'zhou', :password => 'password'}
		realm = 'HttpRequest'

		app = lambda {|env|
			headers = {
         'Content-Type'       => 'text/html'
			}
			[200, headers, 'success!']
		}

		app = Auth::Digest::MD5.new(app) {|user| 
			user == auths[:username] ? 
				Digest::MD5.hexdigest("#{auths[:username]}:#{realm}:#{auths[:password]}") : nil
		}
		app.realm = realm
		app.opaque = 'have a nice day!'
		app.passwords_hashed = true
		run app
	end

	map '/session' do
		app = lambda {|env|
			env['rack.session']['counter'] ||= 0
			env['rack.session']['counter'] += 1
			[200, {'Content-Type' => 'text/html'}, "#{env['rack.session']['counter']}"]
		}
		run Rack::Session::Cookie.new(app)
	end

	map '/session/1' do
		app = lambda {|env|
			env['rack.session']['page1'] = '/session/1'
			response = Response.new
			response.redirect '/session/2', 301
			response.finish
		}
		run Rack::Session::Cookie.new(app)
	end

	map '/session/2' do
		app = lambda {|env|
			env['rack.session']['page2'] = '/session/2'
			[200, 
				    {'Content-Type' => 'text/html'}, 
            "#{env['rack.session']['page1']}:#{env['rack.session']['page2']}"
			]
		}
		run Rack::Session::Cookie.new(app)
	end

	map '/cookie' do
		run lambda {|env|
			response = Response.new
			response.set_cookie 'name', 'zhou'
			response.finish
		}
	end

	map '/upload_file' do
		run lambda {|env|
			request = Request.new env
			data = ''
			if request.params['file']
				file = request.params['file']
				data << file[:filename] + ' - ' + file[:tempfile].read
			end
			params = request.params
			params.delete 'file'
			data << params.inspect if params.size > 0
			[200, {'Content-Type' => 'text/html'}, data]
		}
	end

	map '/upload_file2' do
		run lambda {|env|
			request = Request.new env
			data = ''
			file = request.params['file']
			data << file[:filename] + ' - ' + file[:tempfile].read
			file = request.params['elif']
			data << ", " + file[:filename] + ' - ' + file[:tempfile].read
			[200, {'Content-Type' => 'text/html'}, data]
		}
	end

end

Handler::Mongrel.run builder, :Port => 9527
