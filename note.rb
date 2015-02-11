#!/usr/bin/ruby
# encoding: utf-8

require '~/.scripts/bibus_utils.rb'
require 'curses'
include Curses

# The pointer about where should the item print, and which is the current item
class Pointer
  attr_reader :segment, :location, :len, :pst, :state

  public

  def initialize(array, segsize, pst, state)
    puts 'Warning:: There is an item too long' if segsize < array.max
    @segsize, @len, @pst, @state = segsize, array, pst, state
    @seg, @cur, @segment, @location = 0, 0, [0], [0]
    array.each { |num| addnum(num) }
  end

  def up
    @pst = (@pst + 1) % @len.size
    @segment[@pst] != @segment[@pst - 1]
  end

  def down
    @pst = (@pst - 1) % @len.size
    @segment[@pst] != @segment[(@pst + 1) % @len.size]
  end

  def add(num)
    addnum(num)
    @len << num
    @pst = @len.size - 1
  end

  def page(order)
    (@segment.index(@segment[order])..@segment[0..-2].rindex(@segment[order]))
      .each { |od| yield(od) }
  end

  def chgstat
    @state = @state == :focus ? :picked : :focus
  end

  private

  def addnum(num)
    (@seg, @cur) =
      @cur + num <= @segsize ? [@seg, @cur + num] : chgpage(num)
    @segment << @seg
    @location << @cur
  end

  def chgpage(num)
    @segment[-1], @location[-1] = @segment[-1] + 1, 0
    [@seg + 1, num]
  end
end

# Some methods added to Array
class Array
  def swap!(od1, od2)
    self[od1], self[od2] = self[od2], self[od1]
  end

  def swapud!(order, uord)
    od2 = uord == :u ? (order - 1) % size : (order + 1) % size
    swap!(order, od2)
  end
end

# To store a string in the format with position information of each character
class TxtFile
  attr_reader :curse, :array, :position

  public

  def initialize(string, maxcols)
    @array, @maxcols, @position = string.each_char.to_a << :end, maxcols, []
    @curse = @array.size - 1
    getposition(0)
  end

  def string
    @array[0..-2].join('')
  end

  def each(bgn = 0)
    (bgn..@array.size - 2)
      .each { |ind| yield(letter(ind), x(ind), y(ind)) }
  end

  def letter(curse = @curse)
    @array[curse] == "\n"  ? '' : @array[curse]
  end

  def x(curse = @curse)
    @position[curse][1] < 0 ? @position[curse - 1][1] + 1 : @position[curse][1]
  end

  def y(curse = @curse)
    @position[curse][1] < 0 ? @position[curse - 1][0] : @position[curse][0]
  end

  def addlt(letter)
    @array.insert(@curse, letter)
    getposition(@curse)
    @curse += 1
  end

  def dellt
    @array.delete_at(@curse)
    @curse %= @array.size
    getposition(@curse)
  end

  def move(direct)
    case direct
    when :u then getupline
    when :d then getdownline
    when :l then @curse = (@curse - 1) % @array.size
    when :r then @curse = (@curse + 1) % @array.size
    end
  end

  private

  def getdownline
    (line, cols) = @position[@curse]
    maxline = @position.transpose[0].max
    @curse = line == maxline ? @curse : getcurse(line + 1, cols)
  end

  def getupline
    (line, cols) = @position[@curse]
    @curse = line == 0 ? @curse : getcurse(line - 1, cols)
  end

  def getcurse(line, cols)
    @position.index([line, cols]) || getcurse(line, cols < 0 ? 0 : cols - 1)
  end

  def getposition(bgn)
    @position.pop(@position.size - bgn)
    @array[bgn..-1].reduce(@position) { |a, e| a << nextpos(a, e) }
  end

  def nextpos(pos, letter)
    return [0, 0] if pos.empty?
    addpos = ->(la) { la[1] == @maxcols ? [la[0] + 1, 0] : [la[0], la[1] + 1] }
    letter == "\n" ? [pos.last[0] + 1, -1] : addpos.call(pos.last)
  end
end

# The insert mode
class Insmode
  attr_reader :file

  public

  def initialize(string, head, winsize)
    @file, @head = TxtFile.new(string, winsize[1] - 1), head
    @window = Window.new(winsize[0], winsize[1], head, 0)
    @window.keypad(true)
  end

  def deal
    showstr(0)
    showch

    loop do
      ch = @window.getch
      ch.is_a?(String) ? addch(ch) : control(ch)
      break if ch == KEY_TAB
    end
  end

  private

  MVHASH = { KEY_LEFT => :l, KEY_RIGHT => :r, KEY_UP => :u, KEY_DOWN => :d }
  KEY_DELETE = 263
  KEY_CHGL = 10
  KEY_TAB = 9

  def control(ch)
    case true
    when !MVHASH[ch].nil? then move(MVHASH[ch])
    when ch == KEY_DELETE then delch
    when ch == KEY_CHGL then addch("\n")
    end
  end

  def delch
    @file.move(:l)
    @file.dellt
    refresh
  end

  def refresh
    @window.clear
    showstr(0)
  end

  def addch(ch)
    @file.addlt(ch)
    ch == "\n" ? refresh : showstr(@file.curse - 1)
  end

  def move(direct)
    @file.move(direct)
    showstr
    @window.refresh
  end

  def showch(letter = @file.letter, x = @file.x, y = @file.y)
    @window.setpos(y, x)
    return if (letter == :end) || (letter == '')
    @window.addch(letter)
    @window.setpos(y, x)
  end

  def showstr(bgn = @file.curse)
    @file.each(bgn) { |letter, x, y| showch(letter, x, y) }
    showch
    @window.refresh
  end
end

# The notes with position information
class Note
  attr_reader :notes, :items, :ptr

  public

  def initialize(notes, maxh, maxw)
    (@notes, @maxh, @maxw) = [notes, maxh, maxw]
    @items = notes.split("\n\n").map { |item| dealitem(item) }
    pagediv(0, :focus)
  end

  def item(order)
    @items[order].map { |line| line.join(' ') }.join("\n")
  end

  def mod(item, order)
    @items[order] = dealitem(item)
    pagediv(order)
  end

  def swap(uord)
    @items.swapud!(@ptr.pst, uord)
    pagediv(@ptr.pst)
  end

  def apend(item)
    @items << dealitem(item)
    @ptr.add(@items.last.flatten.size + 2)
  end

  def ins(item, order)
    apend(item)
    return if order < 0
    @items[order..-1] = @items[order..-1].rotate!(-1)
    pagediv(order)
  end

  def delete(order = @ptr.pst)
    @items.delete_at(order)
    pagediv(order -  1, :focus)
  end

  def store
    @notes = (0..@items.size - 1)
      .reduce([]) { |a, e| a << item(e) }.join("\n\n")
  end

  private

  def cutline(line, width)
    chgl =
      ->(arr, wd, wid) { arr.empty? ? true : arr[-1].size + wd.size >= wid }
    line.split(' ').reduce([]) do |a, e|
      chgl.call(a, e, width) ? a << e : a[-1] << " #{e}"
      a
    end
  end

  def dealitem(item)
    item.sub(/\A/, '@@').split("\n").select { |ln| ln != '' }
      .map { |ln| cutline(ln, @maxw).map { |l| l.sub('@@', '  ') } }
  end

  def pagediv(curse = 0, stat = @ptr.state)
    @ptr = Pointer.new(@items.reduce([]) { |a, e| a << e.flatten.size + 2 },
                       @maxh, curse, stat)
  end
end

# The normal mode
class Normode
  attr_reader :note, :height

  public

  def initialize(notes, height, scsize, labwid, bdspc)
    @height, @scsize, @labwid, @bdspc = height, scsize, labwid, bdspc
    @contwid = labwid - 2 - 2 * bdspc

    @note = Note.new(notes, scsize[1] - @height, @contwid)

    @frmleft = (scsize[0] - labwid) / 2
    @conleft = @frmleft + @bdspc + 1
  end

  def insert(order = -1)
    curs_set(1)

    ins = Insmode.new('', @height, [@scsize[1] - @height, @scsize[0]])
    ins.deal
    @note.ins(ins.file.string, order)

    curs_set(0)
    pagerefresh
  end

  def mod(order)
    curs_set(1)

    ins = Insmode.new(@note.item(order), @height,
                      [@scsize[1] - @height, @scsize[0]])
    ins.deal
    @note.mod(ins.file.string, order)

    curs_set(0)
    pagerefresh
  end

  def pagerefresh
    clearpage
    @note.ptr.page(@note.ptr.pst) { |ind| show_note(ind) }
    showcurrent
  end

  def showcurrent
    show_note(@note.ptr.pst, @note.ptr.state)
  end

  def picknote
    @note.ptr.chgstat
    showcurrent
  end

  def move(uord)
    @note.swap(uord) if @note.ptr.state == :picked
    showmessage(@note.ptr.state.to_s)
    show_note
    uord == :u ? @note.ptr.down && pagerefresh : @note.ptr.up && pagerefresh
    showcurrent
  end

  def store_ask
    char = showmessage('Do you want to store this notes?').getch
    @note.store if char == 'y'
  end

  def delete_ask
    char = showmessage('Do you want to delete this item?').getch
    @note.delete && pagerefresh if char == 'y'
  end

  def showmessage(msg)
    win = Window.new(1, @scsize[0], @scsize[1], 0)
    win.addstr(msg)
    win.refresh
    win
  end

  private

  def clearpage
    win = Window.new(@scsize[1], @scsize[0], @height, 0)
    win.refresh
    win.close
  end

  def show_note(order = @note.ptr.pst, state = false)
    height, alti = @note.ptr.len[order], @note.ptr.location[order] + @height
    show_frame(height, alti, state)
    show_cont(order, height - 2, alti + 1)
  end

  def show_cont(order, height, altitude)
    content = Window.new(height , @contwid + 1, altitude, @conleft)
    content.addstr(@note.items[order].join("\n"))
    content.refresh
    content.close
  end

  def show_frame(height, altitude, state)
    frame = Window.new(height, @labwid, altitude, @frmleft)
    state ? frame.box('+', '+') : frame.box('|', '-')
    frame.box('!', '~') if state == :picked
    frame.refresh
  end
end

def showhead(head)
  hd = Note.new(head, lines, cols)
  setpos(0, 0)
  addstr("#{hd.items.join("\n").sub('  ', '')}\n")
  addstr('^' * cols)
  refresh
  hd.items.flatten.size + 1
end

def insdeal(pad, char)
  case char
  when 'a' then pad.insert
  when 'i' then pad.insert(pad.note.ptr.pst)
  when 'm' then pad.mod(pad.note.ptr.pst)
  end
end

def normdeal(pad, char)
  case char
  when 'd' then pad.delete_ask
  when 'p' then pad.picknote
  when 's' then pad.store_ask
  when 'j' then pad.move(:d)
  when 'k' then pad.move(:u)
  end
end

def main(head, notes)
  pad = Normode.new(notes, showhead(head), [cols, lines - 1], cols, 1)
  pad.pagerefresh

  loop do
    char = pad.showmessage('').getch
    normdeal(pad, char) || insdeal(pad, char)
    break if char == 'q'
  end
  pad
end

username = 'linsj'
datafile = '.bibus/Data/Daily.db'
user_s = 'linsj'

bib = BibusSearch.new(username, user_s, datafile)
(ident, author, title, notes) = bib.getnote(ARGV[0])
head = "Title: #{title}\nAuthor: #{author}\nidentifier: #{ident}\n"

init_screen

noecho
curs_set(0)
bib.storenote(ident, main(head, notes).note.notes)

close_screen
