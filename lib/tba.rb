require 'yaml'
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

 def getmatch key
 endpoint = '/event/' + key + '/matches'
 call endpoint 
 end
end

if __FILE__==$0
  tba = TheBlueAlliance.new
  #puts tba.events.map{|e| e['key']}
  event = ARGV[0]
  match = tba.getmatch(event)
  allthematches = {}
  
  match.each do |match|
    matchdata = {}
    matchdata['B1'] = match["alliances"]["blue"]["teams"][0].gsub(/[frc]/, "").to_i
    matchdata['B2'] = match["alliances"]["blue"]["teams"][1].gsub(/[frc]/, "").to_i
    matchdata['B3'] = match["alliances"]["blue"]["teams"][2].gsub(/[frc]/, "").to_i
    matchdata['R1'] = match["alliances"]["red"]["teams"][0].gsub(/[frc]/, "").to_i
    matchdata['R2'] = match["alliances"]["red"]["teams"][1].gsub(/[frc]/, "").to_i
    matchdata['R3'] = match["alliances"]["red"]["teams"][2].gsub(/[frc]/, "").to_i
    allthematches[match["comp_level"] + match["match_number"].to_s] = matchdata
  end
  matchfile = File.open("events/#{event}.yaml", "w")
  matchfile.puts allthematches.to_yaml
  matchfile.close()
end
