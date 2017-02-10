require 'httparty'
require 'json'

class TheBlueAlliance
  raw_config = File.read('./config.yml')
  CONFIG = YAML.load(raw_config)
  include HTTParty
  base_uri 'https://www.thebluealliance.com/api/v2'

  def initialize
    @options = {headers: {'X-TBA-App-Id': 'frc461:couchScout:v0'}}
    @cacheCalls = {}
  end

  def call endpoint, options={}
    if @cacheCalls.has_key? endpoint
      options.merge!({'If-Modified-Since': @cacheCalls[endpoint]['lastmodified']})
    else
      @cacheCalls[endpoint] ||= {}
    end

    puts @options.merge(options)

    response = self.class.get(endpoint, @options.merge(options))
    puts response.code
    puts response.headers
    case response.code
    when 304
      @cacheCalls[endpoint]['body']
    when 200
      @cacheCalls[endpoint]['lastmodified'] = response.headers['last-modified']
      @cacheCalls[endpoint]['body'] = JSON.parse(response.body)
    end
  end

  def events options={}
    call '/events/2017', options
  end
end

if __FILE__==$0
  tba = TheBlueAlliance.new
  puts tba.events.map{|e| e['name']}
end
