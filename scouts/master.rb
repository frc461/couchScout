require './scouts/base.rb'
class ScoutMaster < GenericScout
  def initialize  label, dev, x, y, w, h, serial, ov
    super label, dev, x, y, w, h, serial, ov
    @bg = Curses::COLOR_MAGENTA
    @state = :scoutmaster
    @lines = []
    @line = 0
    @event = {}
    @eline = 0
    @eventFile = 'None'
  end

  def battery_life
      (`cat /sys/class/power_supply/BAT0/charge_now`.to_i / `cat /sys/class/power_supply/BAT0/charge_full`.to_f * 100).round(1)
  end

  def power_status
    `cat /sys/class/power_supply/AC/online` =~ /^1/ ? 'ON AC' : ' BATT'
  end

  def redraw
    @win.clear
    @win.attrset(Curses::color_pair(@bg))
    @h.times do |line|
      text ' '*@w, 0, line
    end
    @win.box '|', '-'

    0.upto(@h - 2) do |i|
        text @lines[i], 1,i+1
    end

    text " - #{@state.to_s.center(@w - 8)} - ", 1, @h - 3
    text "#{power_status}: #{battery_life}", @w - 14, @h - 2
    text Time.now.strftime("%Y-%m-%d %I:%M %p"), 2, @h - 2

    @win.refresh
    
  end

  def run
    @device.each do |event|
      # reject everything but key events
      next unless event.type == 1
      # reject everything but press events
      next unless event.value == 1
      # ignore numlock
      next if event.code == 69

    0.upto(@h - 2) do |i|
        @lines[i] = ''
    end
      case event.code_str
      when "F2"
        @state = :scoutmaster
      when "F3"
        @state = :preview
      when "F4"
        @state = :schedule
      when "F5"
        @state = :chooseschedule
      end
      self.send(@state, event.code_str)
    end

  end 

  def scoutmaster e
     @lines[4] = e.ljust(16) 
     @lines[5] = ''
     redraw
  end

  def preview e
     @lines[5] = e.ljust(16)
     redraw
  end

  def schedule e
     @lines[6] = e.ljust(16) 
     case e
     when /^[0-9]/
       @match_number ||= ''
       @match_number += e
     when 'Enter'
       data = {'tp' => 'ScoutMaster', 'ev' => 'NewMatch', 'events' => @currentmatch, 'match' => @event.keys[@eline]} 
       @overwatch.push data
     when 'Up'
       @eline = @eline - 1 unless @eline < 1
     when 'Down'
       @eline = @eline + 1 unless @eline > @event.length - 2
     end
     @currentmatch = @event[@eline]
     if @currentmatch
       @lines[1] = "Match #{@currentmatch['level']} #{@currentmatch['number']}"
       @lines[4] = "Red Team 1 " + @currentmatch['R1'].to_s
       @lines[5] = "Red Team 2 " + @currentmatch['R2'].to_s
       @lines[6] = "Red Team 3 " + @currentmatch['R3'].to_s
       @lines[7] = "Blue Team 1 " + @currentmatch['B1'].to_s
       @lines[8] = "Blue Team 2 " + @currentmatch['B2'].to_s
       @lines[9] = "Blue Team 3 " + @currentmatch['B3'].to_s
     end
    
     
     redraw
  end
  
  def chooseschedule e
    @events = Dir.glob("events/*.yaml").map{|x| x.gsub(/events/, "")}
    @lines = @events
    case e
      when 'Down'
        @line = @line + 1 unless @line > @events.length - 2 
      when 'Up'
        @line = @line - 1 unless @line < 1
      when 'Enter'
        event_rawyaml = File.read("./events" + @events[@line])
        @event = YAML.load(event_rawyaml)
        @eventFile = @events[@line]
    end
    @lines[11] = @line.to_s
    @lines[10] = @eventFile

    redraw
    Curses.attrset(Curses::color_pair(Curses::COLOR_GREEN))
    text('*' + @lines[@line].to_s + '*', 1, @line + 1)
    Curses.attrset(Curses::A_NORMAL)
    @win.refresh

  end
end
