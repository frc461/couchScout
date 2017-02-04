require 'curses'

class GenericScout
    attr_reader :label, :team, :state
    def initialize label, dev, x, y, w, h, serial=nil
        @device = DevInput.new dev
        @win = Curses::Window.new(h,w,y,x)
        @db = Database.new
        @x = x
        @y = y
        @h = h
        @w = w
        @label = label
        @team = ''
        @state = :prestart
        @match = 0
        @bg = @label.match(/R/) ? Curses::COLOR_RED : Curses::COLOR_BLUE
        @win.bkgd ' '.ord | Curses::color_pair(@bg)
        @uuid = ''
        @lines = ['STARTING UP'.center(15),'CouchScout'.center(16)]
        @serial = serial
        @data = {}
        if serial 
            @serialdev = SerialPort.new(serial, 9600, 8, 1, 0)
        else
            @serialdev = nil
        end
        redraw
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
        text @team.to_s.rjust(4, '0'), 7, 4
        text @match.to_s.rjust(4, '0'), 7, 5
        text @state.to_s, 7, 6
        @lines[0] = @lines[0].ljust(15)
        @lines[1] = @lines[1].ljust(15)

        text @lines[0], 1,1
        text @lines[1], 1,2
        if @serial
            @serialdev.write build_color_array(@bg).chr.join
            @serialdev.write [0xFE, 0x58].chr.join
            @serialdev.write @lines[0]
            @serialdev.write @lines[1]
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
        @device.each do |event|
            # reject everything but key events
            next unless event.type == 1
            # reject everything but press events
            next unless event.value == 1
            # ignore numlock
            next if event.code == 69

            case event.code_str
            when "F5"
                @state = :prestart
            when "F6"
                @state = :auto
            when "F7"
                @state = :teleop
            when "F8"
                @state = :endgame
            when "F9"
                @state = :postmatch
            else
            end
            self.send(@state, event.code_str)
            redraw
        end
    end

    def method_missing m, args
        redraw
        @lines[0] = "MISSING METHOD"
        @lines[1] = m
    end

    def redraw_prestart
      @lines[0] = "#{@team.rjust(4, '0')}          #{label}".ljust(16)
      @lines[1] = "MATCH#{@data['match_number'].to_s.rjust(4, '0')} POS#{@data['start_position']}" 
    end

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
        when 'S'
            @data['start_position'] = 1
        when 'D'
            @data['start_position'] = 2
        when 'F'
            @data['start_position'] = 3
        end
        redraw_prestart
    end

    def redraw_auto
      @lines[0] = "#{@team.rjust(4,'0')} H#{@data['auto_high_goal'].to_s.rjust(2, '0')}  L#{@data['auto_low_goal'].to_s.rjust(2, '0')} #{label}".ljust(16)
      @lines[1] = "G#{@data['auto_gear_pos']} #{@data['baseline_cross'] ? "BC" : '  '} V#{@data['auto_violations']}  DUMP#{@data['auto_hopper']}"
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
            @state = :auto_high_goal
        when 'L'
            @state = :auto_low_goal
        when 'Dot'
          @data['auto_violation'] ||= 0
          if @data['auto_violaton'] < 10
          @data['auto_violation'] += 1
          else
            @data['auto_violation'] = '*'
          end
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
            @data['auto_high_goal'] ||= ''
            if @data['auto_high_goal'].length < 2
                @data['auto_high_goal'] += e
            else @state = :auto
            end
        end
        redraw_auto
    end
    def auto_low_goal e
        case e
        when /^[0-9]$/
            @data['auto_low_goal'] ||= ''

            if @data['auto_low_goal'].length < 2
                @data['auto_low_goal'] += e
            else @state = :auto
            end
        end
        redraw_auto
    end 

    def redraw_teleop
      @lines[0] = "#{@team.rjust(4, '0')}          #{label}".ljust(16)
      @lines[1] = "G#{@data['teleop_gear'].to_s.rjust(2, '0')} D#{@data['teleop_hopper'].to_s.rjust(1, '0')}  #{@data['collect_human'] ? "U" : ' '}#{@data['collect_floor'] ? "I" : ' '}#{@data['collect_hopper'] ? "O" : ' '} #{@data['climbed'] ? "C" : ' '} V#{@data['teleop_violation'].to_s.rjust(1, '0')}" 
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
          if @data['teleop_violation'] < 10
          @data['teleop_violation'] += 1
          else
            @data['teleop_violation'] = '*' #keep counting/ display * only
          end
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
        end
        redraw_teleop
    end

    def endgame e
        @bg = Curses::COLOR_CYAN
        @lines[0] = e.ljust(16) 
    end

    def postmatch e
        @bg = Curses::COLOR_WHITE
        @lines[0] = e.ljust(16) 
    end
