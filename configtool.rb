require 'yaml'
require './lib/devinput.rb'

raw_config = File.read('./config.yml')
config = YAML.load(raw_config)

raw = `cat /proc/bus/input/devices`

blocks = raw.split "\n\n"
devs = []
@queue = Queue.new

blocks.each do |b|
  next unless b.match /sysrq kbd event\d+ leds/
  addr = '/dev/input/' + b.match(/(event\d+)/)[1]
  devs << addr
  puts "Found #{addr}!"
end

threads = []
puts "R1: 1, R2: 2, R3: 3, B1: Q, B2: W, B3: E"
puts 'Make sure the master pushes ENTER last'

devs.each do |d|
  threads << Thread.new do
    dev = DevInput.new d
    label = nil
    dev.each do |e|
      case e.code_str
      when 'Enter'
        label = 'master'
        break
      when '1'
        label = 'R1'
        break
      when '2'
        label = 'R2'
        break
      when '3'
        label = 'R3'
        break
      when 'Q'
        label = 'B1'
        break
      when 'W'
        label = 'B2'
        break
      when 'E'
        label = 'B3'
        break
      end
    end
    @queue.push [label, d]
  end
end

threads.each(&:join)
gets
while !@queue.empty?
  label, dev = *@queue.pop
  config['scouts'][label]['dev'] = dev
end

File.open('config.yml','w') do |h| 
   h.write config.to_yaml
end


