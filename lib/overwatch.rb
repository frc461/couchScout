#Communicate between each module/keyboard/device

class Overwatch
  def initialize
    @pool = {}
  end

  def create label
    @pool[label] = Queue.new
  end

  def push data, match=/.+/
    @pool.each do |l, p|
      p.push data.dup
    end
  end

  def pop label
    @pool[label].pop(false)
  end

  def count label
    if @pool[label]
      @pool[label].length
    else
      0
    end
  end

  def has_message label
    if @pool[label]
      !@pool[label].empty?
    else
      false
    end
  end

  def labels
    @pool.keys
  end

  def inspect
    s = ''
    @pool.each do |l, p|
      s += "#{l}[#{p.length}] "
    end
    s
  end
end
