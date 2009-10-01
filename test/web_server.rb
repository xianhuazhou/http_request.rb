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

end

Handler::Mongrel.run builder, :Port => 9527
