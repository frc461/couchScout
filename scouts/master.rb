require './scouts/base.rb'
class ScoutMaster < GenericScout
  def initialize  label, dev, x, y, w, h, serial, ov
    super label, dev, x, y, w, h, serial, ov
    @bg = Curses::COLOR_MAGENTA
    @state = :scoutmaster
    @lines = []
  end

  def battery_life
      (`cat /sys/class/power_supply/BAT0/charge_now`.to_i / `cat /sys/class/power_supply/BAT0/charge_full`.to_f * 100).round(1)
  end

  def redraw
    @win.clear
    @win.attrset(Curses::color_pair(@bg))
    @h.times do |line|
      text ' '*@w, 0, line
    end
    @win.box '|', '-'

    0.upto(12) do |i|
        text @lines[i], 1,i+1
    end

    text " - #{@state.to_s.center(12)} - ", 4, 13
    text "BATT: #{battery_life}", 24, 14
    text Time.now.strftime("%Y-%m-%d %I:%M %p"), 2, 14

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

      case event.code_str
      when "F2"
        @state = :scoutmaster
      when "F3"
        @state = :preview
      when "F4"
        @state = :schedule
      else
      end
      self.send(@state, event.code_str)
      redraw
    end

  end

  def scoutmaster e
     @lines[4] = e.ljust(16) 
     @lines[5] = ''
  end

  def preview e
     @lines[5] = e.ljust(16) 
  end

  def schedule e
     @lines[6] = e.ljust(16) 
     case e
     when 'P'
       data = {'tp' => 'ScoutMaster', 'ev' => 'NewMatch', 'data' => 'Q57'}
       @overwatch.push data
     end
  end
end
