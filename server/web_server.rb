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

end

Handler::Mongrel.run builder, :Port => 9527
