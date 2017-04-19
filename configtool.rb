#I think youre supposed to run this when starting maybe. Check main.rb

require 'yaml'
require './lib/devinput.rb'

require 'serialport'
require './lib/arrayPatch.rb'

raw_config = File.read('./config.yml')
config = YAML.load(raw_config)

@queue = Queue.new

config['scouts'].each do |label, scout|
  config['scouts'][label]['dev'] = '/dev/null'
  config['scouts'][label]['serial'] = '/dev/null'
end

raw = `cat /proc/bus/input/devices`

blocks = raw.split "\n\n"
devs = []
ttys = []

blocks.each do |b|
  next unless b.match /sysrq kbd event\d+ leds/
  addr = '/dev/input/' + b.match(/(event\d+)/)[1]
  devs << addr
  puts "Found #{addr}!"
end

Dir.glob("/dev/ttyACM*").each do |screen|
  serialdev = SerialPort.new(screen, 9600, 8, 1, 0)

  serialdev.write [0xFE, 0x58].chr.join
  serialdev.write "TYPE #{screen[-1]}"

  ttys << serialdev
end


threads = []
puts "R1: A, R2: S, R3: D, B1: Q, B2: W, B3: E"
puts 'Make sure the master pushes ENTER last'

devs.each do |d|
  threads << Thread.new do
    dev = DevInput.new d
    label = nil
    screen = nil
    dev.each do |e|
        # reject everything but key events
        next unless e.type == 1
        # reject everything but press events
        next unless e.value == 1
        # ignore numlock
        next if e.code == 69

      case e.code_str
      when 'Esc'
        screen = '/dev/null'
      when /[0-9]/
        screen = '/dev/ttyACM' + e.code_str
      when 'Enter'
        label = 'master'
      when 'A'
        label = 'R1'
      when 'S'
        label = 'R2'
      when 'D'
        label = 'R3'
      when 'Q'
        label = 'B1'
      when 'W'
        label = 'B2'
      when 'E'
        label = 'B3'
      end
      puts [label, d, screen].join ' - '
      if label && screen
        @queue.push [label, d, screen]
        break
      end
    end
  end
end

threads.each(&:join)
puts 'Done'

while !@queue.empty?
  label, dev, ser = *@queue.pop
  puts "*#{label}: #{dev} / #{ser}"
  config['scouts'][label]['dev'] = dev
  config['scouts'][label]['serial'] = ser
end

File.open('config.yml','w') do |h| 
  h.write config.to_yaml
end


