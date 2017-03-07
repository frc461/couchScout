require 'curses'

class GenericScout
  attr_reader :label, :team, :state

  def initialize label, dev, x, y, w, h, serial, ov
    @device = DevInput.new dev unless dev == '/dev/null'
    @win = Curses::Window.new(h,w,y,x)
    @db = Database.new
    @x = x
    @y = y
    @h = h
    @w = w
    @label = label
    @team = ''
    @state = :prestart
    @match = nil
    @event = 'NO EVENT'
    @matchq = Queue.new
    @bg = @label.match(/R/) ? Curses::COLOR_RED : Curses::COLOR_BLUE
    @win.bkgd ' '.ord | Curses::color_pair(@bg)
    @uuid = ''
    @lines = ['STARTING UP'.center(15),'CouchScout'.center(16)]
    @serial = serial unless serial == '/dev/null'
    @data = {}
    @overwatch = ov
    @database = Database.new
    if serial  && serial != '/dev/null'
      @serialdev = SerialPort.new(serial, 9600, 8, 1, 0)
    else
      @serialdev = nil
    end
    redraw
    initialize_data
  end
  
  def inspect
    @state + ' ' + @label
  end

    def initialize_data
    @data = {}
    @data['start_position'] = 0
    @data['auto_high_goal'] = ''
    @data['auto_low_goal'] =''
    @data['auto_gear_pos'] = 0
    @data['auto_baseline'] = false
    @data['auto_violaion'] = 0
    @data['auto_hopper'] = 0
    @data['teleop_violation'] = 0
    @data['teleop_high_goal'] = ['']
    @data['teleop_low_goal'] = ['']
    @data['teleop_gear'] = 0
    @data['teleop_hopper'] = 0
    @data['collect_human'] = false
    @data['collect_floor'] = false
    @data['collect_hopper'] = false
    @data['climbed'] = false
    @data['comments'] = ''
    @data['event'] = ''
    end

  def build_color_array(color)
    arr = [0xFE, 0xD0]
    case color
    when Curses::COLOR_BLACK
      arr << [0,0,0]
    when Curses::COLOR_WHITE
      arr << [255, 255, 255]
    when Curses::COLOR_RED
      arr << [255, 0, 0]
    when Curses::COLOR_BLUE
      arr << [0,0,255]
    when Curses::COLOR_GREEN
      arr << [0,255,0]
    when Curses::COLOR_YELLOW
      arr << [255,255,0]
    when Curses::COLOR_MAGENTA
      arr << [255,0,255]
    when Curses::COLOR_CYAN
      arr << [0,255,255]
    else 
      arr << [255,255,255]
    end
    arr
  end

  def text str, x, y
    @win.setpos y, x
    @win.addstr str.to_s
  end

  def redraw
    @win.clear
    @win.attrset(Curses::color_pair(@bg))
    @h.times do |line|
      text ' '*@w, 0, line
    end
    @win.box 'x', 'x'
    text '-'*16, 1, 3
    text @label, 15, 4
    text " TEAM", 1, 4
    text "MATCH", 1, 5
    text "PHASE", 1, 6
    text @overwatch.count(@label).to_s.rjust(2, '0'), 15, 5
    text @team.to_s.rjust(4, '0'), 7, 4
    text @match.to_s.rjust(4, '0'), 7, 5
    text @state.to_s, 7, 6
    text @event.to_s, 3, 7
    @lines[0] = @lines[0].ljust(15)
    @lines[1] = @lines[1].ljust(15)

    text @lines[0], 1,1
    text @lines[1], 1,2
    if @serial
      @serialdev.write build_color_array(@bg).chr.join
      @serialdev.write [0xFE, 0x58].chr.join 
      @serialdev.write [0xFE, 0x47, 1, 1].chr.join 
      @serialdev.write @lines[0].ljust(15)
      @serialdev.write [0xFE, 0x47, 1, 2].chr.join 
      @serialdev.write @lines[1].ljust(15)
    end

    @win.refresh
  end

  def safe?
    true
  end

  def new_match
    @uuid = @db.uuid
  end

  def run
    if @device
      @device.each do |event|
        # reject everything but key events
        next unless event.type == 1
        # reject everything but press events
        next unless event.value == 1
        # ignore numlock
        next if event.code == 69

        while(@overwatch.has_message(@label))
          message = @overwatch.pop(@label)
          topic = message.delete('tp')
          ev = message.delete('ev')
          parse_message(topic, ev, message)
        end
        
        if !@match && @matchq.length == 0
          @lines[0] = "     WAITING    "
          @lines[1] = "     .......    "
          redraw
          message = @overwatch.pop(@label)
          topic = message.delete('tp')
          ev = message.delete('ev')
          parse_message(topic, ev, message)
          tmp = @matchq.pop
          @match = tmp[0]
          @team = tmp[1][@label].to_s
          @event = tmp[2].to_s
        end


        case event.code_str
        when "F5"
          if @serial
            @serialdev.write [0xFE, 0x52].chr.join
          end
          @state = :prestart
        when "F6"
          if @serial
            @serialdev.write [0xFE, 0x52].chr.join
          end
          @state = :auto
        when "F7"
          if @serial
            @serialdev.write [0xFE, 0x52].chr.join
          end
          @state = :teleop
        when "F8"
          if @serial
            #@serialdev.write [0xFE, 0x51].chr.join
          end
          @state = :postmatch
        else
        end
        self.send(@state, event.code_str)
        redraw
      end
    end
  end

  #def method_missing m, args
  #  redraw
  #  @lines[0] = "MISSING METHOD"
  #  @lines[1] = m
  #end

  def redraw_prestart
    @lines[0] = "#{(@team.to_s || 'X').rjust(4, '0')}          #{label}".ljust(16)
    @lines[1] = "MATCH#{@match.to_s.rjust(4, '0')} POS#{@data['start_position']}" 
  end


  def prestart e
    @bg = @label.match(/R/) ? Curses::COLOR_RED : Curses::COLOR_BLUE
    case e
    when /^[0-9]$/
      if @team.length < 4
        @team += e
      end
    when 'Backspace'
      @team = @team[0...-1]
    when 'Q'
      @data['start_position'] = 1
    when 'W'
      @data['start_position'] = 2
    when 'E'
      @data['start_position'] = 3
    when 'Esc'
      if !@matchq.empty?
      tmp = @matchq.pop
      @match = tmp[0]
      @team = tmp[1][@label].to_s
      @event = tmp[2].to_s
      @data['team'] = @team
      end
    end
    redraw_prestart
  end

  def redraw_auto
    @lines[0] = "#{@team.rjust(4,'0')} H#{@data['auto_high_goal'].to_s.rjust(2, '0')}  L#{@data['auto_low_goal'].to_s.rjust(2, '0')} #{label}".ljust(16)
    @lines[1] = "G#{@data['auto_gear_pos']} #{@data['baseline_cross'] ? "BC" : '  '} V#{@data['auto_violation']}  DUMP#{@data['auto_hopper']}"
  end

  def auto e
    @bg = Curses::COLOR_YELLOW
    case e
    when 'B'
      if @data['baseline_cross'] == true
        @data['baseline_cross'] = false
      else
        @data['baseline_cross'] = true
      end
    when 'S'
      @data['auto_hopper'] ||= 0
      if @data['auto_hopper'] > 0
        @data['auto_hopper'] -= 1
      end
    when 'D'
      @data['auto_hopper'] ||= 0
      if @data['auto_hopper'] < 5
        @data['auto_hopper'] += 1
      end
    when 'G'
      @state = :auto_gear
    when 'H'
      @data['auto_high_goal'] = ''
      @state = :auto_high_goal
    when 'L'
      @data['auto_low_goal'] = ''
      @state = :auto_low_goal
    when 'Dot'
      @data['auto_violation'] ||= 0
      @data['auto_violation'] += 1
    when 'Comma'
      @data['auto_violation'] ||= 0
      if @data['auto_violation'] > 0
        @data['auto_violation'] -= 1
      end
    end
    redraw_auto
  end

  def auto_gear e
    case  e
    when '1'
      @data['auto_gear_pos'] = 1
      @state = :auto
    when '2'
      @data['auto_gear_pos'] = 2
      @state = :auto
    when '3'
      @data['auto_gear_pos'] = 3
      @state = :auto
    end
    redraw_auto
  end
  
  def auto_high_goal e
    case e     
    when /^[0-9]$/
      @data['auto_high_goal'] += e
      @state = :auto if @data['auto_high_goal'].length >= 2
    end
    redraw_auto
  end

  def auto_low_goal e
    case e
    when /^[0-9]$/
      @data['auto_low_goal'] += e
      @state = :auto if @data['auto_low_goal'].length >= 2
    end
    redraw_auto
  end 

  def redraw_teleop
    @lines[0] = "#{@team.rjust(4, '0')} H#{(@data['teleop_high_goal'] || []).last.to_s.rjust(2, '0')} L#{(@data['teleop_low_goal'] || []).last.to_s.rjust(2, '0')}  #{label}".ljust(15)[0..15]
    @lines[1] = "G#{@data['teleop_gear'].to_s.rjust(2, '0')} D#{@data['teleop_hopper'].to_s.rjust(1, '0')}  #{@data['collect_human'] ? "P" : ' '}#{@data['collect_floor'] ? "F" : ' '}#{@data['collect_hopper'] ? "H" : ' '} #{@data['climbed'] ? "C" : ' '} V#{(@data['teleop_violation'] || 0) > 9 ? '*' : @data['teleop_violation'].to_s.rjust(1, '0')}" 
  end

  def teleop e
    @bg = Curses::COLOR_GREEN
    @lines[0] = e.ljust(16)

    case e
    when 'C'
      if @data['climbed'] == true
        @data['climbed'] = false
      else 
        @data['climbed'] = true
      end
    when 'G'
      @data['teleop_gear'] ||= 0
      if @data['teleop_gear'] < 16
        @data['teleop_gear'] += 1
      end
    when 'F'
      @data['teleop_gear'] ||= 0
      if @data['teleop_gear'] > 0
        @data['teleop_gear'] -= 1
      end
    when 'S'
      @data['teleop_hopper'] ||= 0
      if @data['teleop_hopper'] > 0
        @data['teleop_hopper'] -= 1
      end
    when 'D'
      @data['teleop_hopper'] ||= 0
      if @data['teleop_hopper'] < 5
        @data['teleop_hopper'] += 1
      end

    when 'Dot'
      @data['teleop_violation'] ||= 0
      @data['teleop_violation'] += 1 
    when 'Comma'
      @data['teleop_violation'] ||= 0
      if @data['teleop_violation'] > 0
        @data['teleop_violation'] -= 1
      end
    when 'U'
      if @data['collect_human'] == true
        @data['collect_human'] = false
      else
        @data['collect_human'] = true
      end
    when 'I'
      if @data['collect_floor'] == true
        @data['collect_floor'] = false
      else
        @data['collect_floor'] = true
      end
    when 'O'
      if @data['collect_hopper'] == true
        @data['collect_hopper'] = false
      else
        @data['collect_hopper'] = true
      end
    when 'H'
      @state = :teleop_high_goal
    when 'L'
      @state = :teleop_low_goal
    end
    redraw_teleop
  end


  def teleop_high_goal e
    case e     
    when /^[0-9]$/
      @data['teleop_high_goal'] ||= ['']
      if @data['teleop_high_goal'][-1].length == 0
        @data['teleop_high_goal'][-1] += e
      elsif @data['teleop_high_goal'].last.length == 1
        @data['teleop_high_goal'][-1] += e
        @state = :teleop
      else 
        @data['teleop_high_goal'] << e
      end
    end
    redraw_teleop
  end

  def teleop_low_goal e
    case e
    when /^[0-9]$/
      @data['teleop_low_goal'] ||= ['']   
      if @data['teleop_low_goal'][-1].length == 0
        @data['teleop_low_goal'][-1] += e
      elsif @data['teleop_low_goal'].last.length == 1
        @data['teleop_low_goal'][-1] += e
        @state = :teleop
      else 
        @data['teleop_low_goal'] << e
      end
    end
    redraw_teleop
  end

  def redraw_postmatch
    @data['comments'] ||= ''
    lines = @data['comments'].scan(/.{1,16}/)
    @lines[0] = lines[-2] || ''
    @lines[1] = lines[-1] || ''
  end

  def postmatch e
    @bg = Curses::COLOR_WHITE
    @lines[0] = e.ljust(16)
    case e
    when /^[A-Z0-9]$/
      @data['comments'] += e
    when 'Backspace'
      @data['comments'] = @data['comments'][0...-1]
    when 'Space'
      @data['comments'] = @data['comments'] + " "
    when 'Dot'
      @data['comments'] = @data['comments'] + "."
    when 'Comma'
      @data['comments'] = @data['comments'] + ","
    when 'Slash'
      @data['comments'] = @data['comments'] + "?"
    when 'Esc'
      @bg = Curses::COLOR_CYAN
      @lines[0] = "     SAVING     "
      @lines[1] = "     ......     "
      redraw
      @data['team'] = @team
      @data['type'] = "Match"
      @data['position'] = @label
      @data['match'] = @match
      @data['event'] = @event
      @database.pushData(@data)
      initialize_data
      @lines[0] = "     WAITING    "
      @lines[1] = "     .......    "
      redraw
      unless @matchq.length > 0
          message = @overwatch.pop(@label)
          topic = message.delete('tp')
          ev = message.delete('ev')
          parse_message(topic, ev, message)
      end
      tmp = @matchq.pop
      @match = tmp[0]
      @team = tmp[1][@label].to_s
      @event = tmp[2].to_s

      
      @state = :prestart
      redraw_prestart
    end
    redraw_postmatch unless @state == :prestart
  end

  def parse_message topic, event, data
    case event
    when 'NewMatch'
      @matchq.push [data['match'], data['events'], data['event']]
    end
    redraw
  end
end
