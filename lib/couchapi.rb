
class Database
  raw_config = File.read('./config.yml')
  CONFIG = YAML.load(raw_config)
  include HTTParty
  base_uri CONFIG['database_url']
  @database = CONFIG['couch_database']

  def initialize
    @options = {headers: {Referer: CONFIG['database_url']}}
  end

  def uuid
    JSON.parse(self.class.get('/_uuids', @options).body)['uuids'].first
  end

  def pushData data
    response = JSON.parse(self.class.put("/#{@database}/" + uuid, body: data.to_json, headers: {Referer: 'vps.boilerinvasion.org'}).body)
  end

  def databases
    self.class.get()
  end
end
