#Communicate with couchdb server (local)

require 'httparty'
require 'yaml'
require 'json'
require 'csv'

class Database
  attr_accessor :database, :options
  raw_config = File.read('./config.yml')
  CONFIG = YAML.load(raw_config)
  include HTTParty
  base_uri CONFIG['database_url']

  def initialize
    @options = {headers: {Referer: CONFIG['database_url'].split('/')[0...2].join('') }}
    @database = CONFIG['couch_database'] || 'test'
  end

  def uuid
    JSON.parse(self.class.get('/_uuids').body)['uuids'].first
  end

  def getView p1, keyFilter=nil
    designdoc = p1
    view = p1
    if keyFilter
      endpoint = "/#{@database}/_design/#{designdoc}/_view/#{view}?key=#{CGI.escape('"' + keyFilter + '"')}"
    else
      endpoint = "/#{@database}/_design/#{designdoc}/_view/#{view}"
    end
    puts endpoint
    response = JSON.parse(self.class.get(endpoint).body)
  end

  def pushData data
    response = JSON.parse(self.class.put("/#{@database}/" + uuid, body: data.to_json ).body)
  end

  def databases
    self.class.get()
  end

  def matches_for(team)
    if res=getView('getMatches')
      if res['rows']
        res['rows'].map{|e| e['value']}
      else
        nil
      end
    else
      nil
    end
  end

  def match_for(team_match_event)
    if res=getView('getEventTeamMatch', team_match_event.downcase)
      if res['rows']
        res['rows'].map{|e| e['value']}.first
      else
        nil
      end
    else
      nil
    end
  end
end


if __FILE__==$0
  tba = Database.new
  puts tba.database
  data = tba.getView('getMatches')['rows'].map{|r| r['value']}
  CSV.open("data.csv","w") do |csv|
    csv << ['event', 'team', 'match', 'position', 'start_position', 'auto_high_goal', 'auto_low_goal', 'auto_gear', 'teleop_gears', 'teleop_high_goal', 'teleop_low_goal',  'climb']
    data.each do |d|
      csv << [d['event'], d['team'], d['match'], d['position'], d['start_position'], d['auto_high_goal'], d['auto_low_goal'], (d['auto_gear_pos'].to_i > 0 ? 1 : 0), d['teleop_gear'].to_i, d['teleop_high_goal'].map{|i| i.to_i}.inject(&:+), d['teleop_low_goal'].map{|i| i.to_i}.inject(&:+), (d['climbed'] ? 1 : 0), d['comments']]
    end
  end
end
