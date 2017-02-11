require 'httparty'
require 'yaml'
require 'json'

class Database
  raw_config = File.read('./config.yml')
  CONFIG = YAML.load(raw_config)
  include HTTParty
  base_uri CONFIG['database_url']
  @database = CONFIG['couch_database'] || 'test'

  def initialize
    @options = {headers: {Referer: CONFIG['database_url']}}
  end

  def uuid
    JSON.parse(self.class.get('/_uuids', @options).body)['uuids'].first
  end

  def getView p1, p2=nil
    designdoc = p1
    view = p2 || p1
    endpoint = "/test/_design/#{designdoc}/_view/#{view}"
    puts endpoint
    
    response = JSON.parse(self.class.get(endpoint, headers: {Referer: 'vps.boilerinvasion.org'}).body)
  end

  def pushData data
    response = JSON.parse(self.class.put("/test/" + uuid, body: data.to_json, headers: {Referer: 'vps.boilerinvasion.org'}).body)
  end

  def databases
    self.class.get()
  end
end

if __FILE__==$0
  tba = Database.new
  puts tba.getView 'getMatches'
end
