#!/usr/bin/env ruby
# saba-load-requester - Send HTTP requests at specified frequency
# Copyright (c) 2024 Kenshi Muto
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'net/http'
require 'open3'
require_relative 'config'

def get_status
  o, ret = Open3.capture2('mkr status -v --jq ".memo"')
  o.each_line do |l|
    status = l.chomp
    if @config.keys.include?(status)
      return status
    end
  end
  nil
end

def make_requests(status)
  requests = []
  @config[status].each do |v|
    1.upto(MINUTES) do
      v2 = v - (rand() * (MINUS_RANGE + 1)).to_i
      v2 = 0 if v2 < 0
      requests.push(v2)
    end
  end
  requests
end

uri = URI.parse(LB_URL)
current_status = DEFAULT_MODE
threads = []

while true
  requests = make_requests(current_status)

  requests.each do |v|
    status = get_status

    if status && status != current_status
      current_status = status
      break
    elsif status.nil? && current_status != DEFAULT_MODE
      current_status = DEFAULT_MODE
      break
    end

    STDERR.puts "#{current_status}:#{v}"

    if v == 0
      sleep(60)
      next
    end

    1.upto(v) do
      threads << Thread.new do
        STDERR.puts Time.now if ENV['DEBUG']
        Net::HTTP.get_response(uri)
      end
      sleep(60.to_f / v)
    end
  end
end
