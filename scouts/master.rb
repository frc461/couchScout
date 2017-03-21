require './scouts/base.rb'
class ScoutMaster < GenericScout
  def initialize  label, dev, x, y, w, h, serial, ov
    super label, dev, x, y, w, h, serial, ov
    @bg = Curses::COLOR_MAGENTA
    @state = :chooseschedule
    @lines = []
    @line = 0
    @event = {}
    @eline = 0
    @eventFile = 'None'
    @team_entry = ''
    @team_entry2 = ''
    @match_entry = ''
    @current_event = ''
    @focus = nil
    @matches = []
    @match = {}
    @team_event_match = ''
    chooseschedule ' '
    initialize_master_comments
  end
  def initialize_master_comments
    @masterdata = {}
    @masterdata['comments'] = ''
    @masterdata['team_entry2'] = ''
    @masterdata['match_entry'] = ''
  end
  def inspect
    'ScoutMaster'
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
      oldstate = @state
      case event.code_str
      when "F2"
        @state = :chooseschedule
      when "F3"
        @state = :schedule
      when "F4"
        @state = :manualmatch
      when "F12"
        @state = :displaydata
      when "F11"
        @state = :masterediting
      when "F9"
        @state = :mastercomments
      end
      @focus = nil if oldstate != @state
      self.send(@state, event.code_str)
    end

  end 

  def schedule e
    @lines[6] = e.ljust(16) 
    case e
    when /^[0-9]/
      _i_number ||= ''
      @match_number += e
    when 'Enter'
      data = {'tp' => 'ScoutMaster', 'ev' => 'NewMatch', 'events' => @currentmatch, 'match' => @event[@eline]['level'] + @event[@eline]['number'].to_s, 'event' => @current_event} 
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
      @current_event = @events[@eline].match(/([a-zA-Z0-9]+)\.yaml/)[1]
      event_rawyaml = File.read("./events" + @events[@line])
      @event = YAML.load(event_rawyaml)
      @eventFile = @events[@line]
    when /^[A-Z0-9]$/
      @current_event += e
    end
    @lines[10] = "Current Event: " + (@current_event || 'NONE')

    redraw
    Curses.attrset(Curses::color_pair(Curses::COLOR_GREEN))
    text('*' + @lines[@line].to_s + '*', 1, @line + 1)
    Curses.attrset(Curses::A_NORMAL)
    @win.refresh
  end

  MANUALMODES = ['level', 'number', 'R1', 'R2', 'R3', 'B1', 'B2', 'B3']

  def manualmatch e
    @focus ||= 'level'
    case e
    when 'Esc'
      @currentmatch = {}
      @currentmatch['level'] = ''
      @currentmatch['number'] = ''
      @currentmatch['R1'] = ''
      @currentmatch['R2'] = ''
      @currentmatch['R3'] = ''
      @currentmatch['B1'] = ''
      @currentmatch['B2'] = ''
      @currentmatch['B3'] = ''
      @focus = 'level'
    when 'Tab'
      @focus = MANUALMODES[MANUALMODES.index(@focus) + 1]
      @focus ||= 'level'
    when /^[A-Z0-9]$/
      @currentmatch[@focus] += e
    when 'Backspace'
      @currentmatch[@focus] = @currentmatch[@focus][0...-1]
    when 'Enter'
      data = {'tp' => 'ScoutMaster', 'ev' => 'NewMatch', 'events' => @currentmatch, 'match' => @currentmatch['level'] + @currentmatch['number'].to_s, 'event' => @current_event} 
      @overwatch.push data
    end
    @lines[12] = e
    @lines[13] = @currentmatch.inspect

    if @currentmatch
      @lines[1] = 'Editing ' + @focus 
      @lines[2] = "Match #{@currentmatch['level']} #{@currentmatch['number']}"
      @lines[4] = "Red Team 1 " + @currentmatch['R1'].to_s
      @lines[5] = "Red Team 2 " + @currentmatch['R2'].to_s
      @lines[6] = "Red Team 3 " + @currentmatch['R3'].to_s
      @lines[7] = "Blue Team 1 " + @currentmatch['B1'].to_s
      @lines[8] = "Blue Team 2 " + @currentmatch['B2'].to_s
      @lines[9] = "Blue Team 3 " + @currentmatch['B3'].to_s
    end

    redraw
  end

  def displaydata e
    case e
    when /^[0-9]$/
      @team_entry += e
    when 'Backspace'
      @team_entry = @team_entry[0...-1]
    when 'Enter'
      @matches = @database.matches_for @team_entry
      @match_index = 0
    when 'Left'
      @match_index -= 1 unless @match_index == 0
    when 'Right'
      @match_index += 1 unless @match_index == @matches.count-1
    end
    displayteamdata
    redraw
  end

  def displayteamdata
    @lines[1] = "Team: " + @team_entry 
    if @matches && @matches.count > 0
      @lines[2] = @matches[@match_index]['event'] + " match " + @matches[@match_index]['match']
      @lines[3] = "Auto Info:"
      @lines[4] = "   start position: " + @matches[@match_index]['start_position'].to_s + " | auto high goals: " + @matches[@match_index]['auto_high_goal'].to_s + " | auto low goals: " + @matches[@match_index]['auto_low_goal'].to_s
      @lines[5] = "   auto gear position: " + @matches[@match_index]['auto_gear_pos'].to_s + " | baseline cross: " + @matches[@match_index]['baseline_cross'].to_s + " | auto violations: " + @matches[@match_index]['auto_violation'].to_s
      @lines[6] = "   auto hoppers: " + @matches[@match_index]['auto_hopper'].to_s
      @lines[7] = "Teleop Info:"
      @lines[8] = "   teleop high goals: " + @matches[@match_index]['teleop_high_goal'].to_s + " | teleop low goals: " + @matches[@match_index]['teleop_low_goal'].to_s
      @lines[9] = "   teleop gears: " + @matches[@match_index]['teleop_gear'].to_s + " | teleop hoppers: " + @matches[@match_index]['teleop_hopper'].to_s + " | human collection: " + @matches[@match_index]['collect_human'].to_s 
      @lines[10] = "   floor collection: " + @matches[@match_index]['collect_floor'].to_s + " | hopper collection: " + @matches[@match_index]['collect_hopper'].to_s
      @lines[11] = "   climbed: " + @matches[@match_index]['climbed'].to_s + " | teleop violations: " + @matches[@match_index]['teleop_violation'].to_s
      @lines[12] = "Comments:"
      @lines[13] = "   " + @matches[@match_index]['comments'][0...64].to_s
      @lines[14] = "   " + @matches[@match_index]['comments'][69...129].to_s
      @lines[14] = "   " + @matches[@match_index]['comments'][138...193].to_s
    end
  end
  def mastercomments e
    case e
    when "F10"
      @state = :teamedit
    when "F8"
      @state = :matchedit
    when /^[A-Z0-9]$/
      @masterdata['comments'] += e
    when 'Backspace'
      @masterdata['comments'] = @masterdata['comments'][0...-1]
    when 'Space'
      @masterdata['comments'] = @masterdata['comments'] + " "
    when 'Dot'
      @masterdata['comments'] = @masterdata['comments'] + "."
    when 'Comma'
      @masterdata['comments'] = @masterdata['comments'] + ","
    when 'Slash'
      @masterdata['comments'] = @masterdata['comments'] + "?"
    when 'Esc'
      @database.pushData(@masterdata)
      initialize_master_comments
    end
    @lines[1] = "Team: " + @masterdata['team_entry2']
    @lines[2] = "Match: " + @masterdata['match_entry']
    @lines[3] = "   " + @masterdata['comments'][0...64].to_s
    @lines[4] = "   " + @masterdata['comments'][69...129].to_s
    @lines[5] = "   " + @masterdata['comments'][138...193].to_s
    redraw
  end
  def teamedit e
    case e
    when /^[0-9]$/
      @masterdata['team_entry2'] += e
    when 'Backspace'
      @masterdata['team_entry2'] = @masterdata['team_entry2'][0...-1]
    when 'Enter'
      @state = :mastercomments
    end
  end
  def matchedit e
    case e
    when /^[0-9]$/
      @masterdata['match_entry'] += e
    when 'Backspace'
      @masterdata['match_entry'] = @masterdata['match_entry'][0...-1]
    when 'Enter'
      @state = :mastercomments
    end
  end
  def masterediting e
    if @match['comments'] 
      case e
      when /^[A-Z0-9]$/
        @match['comments'] += e
      when 'Backspace'
        @match['comments'] = @match['comments'][0...-1]
      when 'Space'
        @match['comments'] = @match['comments'] + " "
      when 'Dot'
        @match['comments'] = @match['comments'] + "."
      when 'Comma'
        @match['comments'] = @match['comments'] + ","
      when 'Slash'
        @match['comments'] = @match['comments'] + "?"
      when 'Esc'
        @database.pushData(@match['comments'])
      end
    else
      case e
      when /^[A-Z0-9]$/
        @team_event_match+= e
      when 'Backspace'
        @team_event_match = @team_event_match[0...-1]
      when 'Minus'
        @team_event_match = @team_event_match + "-"
      when 'Esc'
        @match = @database.match_for @team_event_match 
      end
    end
    @lines[1] = @team_event_match
    @lines[2] = "Team: " + @match['team'].to_s
    @lines[3] = "Match: " + @match['match'].to_s
    @lines[4] = @match['comments'].to_s[0...64].to_s
    @lines[5] = @match['comments'].to_s[65...129].to_s
    @lines[6] = @match['comments'].to_s[130...193].to_s
    redraw
  end
end
