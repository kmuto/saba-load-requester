#!/usr/bin/env ruby
require 'net/http'
require 'open3'

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

# 5分間の実行
MINUTES = 5
ALB_URL = "http://localhost"
MINUS_RANGE = 5

@config = {
  'lowload' => [20],
  'highload' => [90],
  'spike' => [90, 90, 20, 20, 20, 20, 20],
  'wave' => [20, 30, 40, 50, 60, 70, 80, 90, 80, 70, 60, 50, 40, 30]
}

DEFAULT_MODE = 'lowload'

uri = URI.parse(ALB_URL)

current_status = DEFAULT_MODE
requests = make_requests(current_status)

reload = nil

while true
  if reload
    requests = make_requests(current_status)
    reload = nil
  end

  requests.each do |v|
    status = get_status
    if status && status != current_status
      current_status = status
      reload = true
      break
    elsif status.nil? && current_status != DEFAULT_MODE
      current_status = DEFAULT_MODE
      reload = true
      break
    end

    if v == 0
      sleep(60)
      next
    end

    1.upto(v) do
      Net::HTTP.get_response(uri)
      sleep(60.to_f / v)
    end
  end
end
