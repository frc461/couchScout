
class Database
  raw_config = File.read('./config.yml')
  CONFIG = YAML.load(raw_config)
  include HTTParty
  base_uri CONFIG['database_url']

  def initialize
    @options = {headers: {Referer: CONFIG['database_url']}}
  end

  def uuid
    JSON.parse(self.class.get('/_uuids', @options).body)['uuids'].first
  end

  def databases
    self.class.get()
  end
end
