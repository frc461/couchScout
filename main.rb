require 'yaml'
require 'json'

require 'bundler'
Bundler.require

Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/scouts/*.rb'].each {|file| require file }

raw_config = File.read('./config.yml')
CONFIG = YAML.load(raw_config)

CONFIG['scouts'].map{|k, s| s['serial'] || nil}.delete_if{|s| s == nil}.each do |y|
  puts 'Waiting on serial ports'
  waiting = true
  while waiting
    sleep 1
    print '.'
    waiting = `lsof /dev/ttyACM*` =~ /Modem/
  end
end

threadpool = []
workers = {}
overwatch = Overwatch.new

include Curses



begin
  `stty -echo`
  init_screen
  start_color
  noecho
  cbreak

  init_pair(COLOR_WHITE, COLOR_BLACK, COLOR_WHITE)
  init_pair(COLOR_RED, COLOR_WHITE, COLOR_RED)
  init_pair(COLOR_BLUE, COLOR_WHITE, COLOR_BLUE)
  init_pair(COLOR_GREEN, COLOR_BLACK, COLOR_GREEN)
  init_pair(COLOR_YELLOW, COLOR_BLACK, COLOR_YELLOW)
  init_pair(COLOR_MAGENTA, COLOR_WHITE, COLOR_MAGENTA)
  init_pair(COLOR_CYAN, COLOR_BLACK, COLOR_CYAN)
  init_pair(COLOR_BLACK, COLOR_WHITE, COLOR_BLACK)

  CONFIG['scouts'].each do |label, cnf|
    w = Object::const_get(cnf['worker']).new(label, cnf['dev'], cnf['x'], cnf['y'], cnf['w'], cnf['h'], cnf['serial'], overwatch)
    overwatch.create label
    workers[cnf['label']] = w
    threadpool << Thread.new{w.run}
    w.redraw
  end

  trap "SIGINT" do
    safe = true
    workers.each do |k, w|
      safe = false unless w.safe?
    end

    if safe
      close_screen
      threadpool.each(&:kill)

      workers.each do |w|
        puts w.inspect
      end
      puts workers.inspect

      puts "Goodbye"
    else
    end
  end

  threadpool.each(&:join)
ensure
  `stty echo`
  `clear`
end
