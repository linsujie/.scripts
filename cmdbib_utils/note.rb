#!/usr/bin/env ruby
# encoding: utf-8


require File.expand_path('../insert.rb', __FILE__)
require File.expand_path('../pointer.rb', __FILE__)

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


# The notes with position information
class Note
  attr_reader :notes, :items, :ptr, :changed

  public

  def initialize(notes, maxh, maxw)
    @notes, @maxh, @maxw, @changed = notes, maxh, maxw, false
    @items = notes.split("\n\n").map { |item| dealitem(item) }
    pagediv(0, :focus)
  end

  def item(order)
    @items[order].map { |line| line.join(' ') }.join("\n")
  end

  def mod(item, order)
    @changed = true
    @items[order] = dealitem(item)
    pagediv(order)
  end

  def swap(uord)
    @changed = true
    @items.swapud!(@ptr.pst, uord)
    pagediv(@ptr.pst)
  end

  def apend(item)
    @changed = true
    @items << dealitem(item)
    @ptr.add(@items.last.flatten.size + 2)
  end

  def ins(item, order)
    @changed = true
    apend(item)
    return if order < 0
    @items[order..-1] = @items[order..-1].rotate!(-1)
    pagediv(order)
  end

  def delete(order = @ptr.pst)
    @changed = true
    @items.delete_at(order)
    pagediv(order > 0 ? order -  1 : order, :focus)
  end

  def store
    @changed = false
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
    
    item.sub(/\A\s*/, '@@').split("\n").select { |ln| ln != '' }
      .map { |ln| cutline(ln, @maxw).map { |l| l.sub('@@', '   ') } } 
  end

  def pagediv(curse = 0, stat = @ptr.state)
    @ptr = Pointer.new(@items.reduce([]) { |a, e| a << e.flatten.size + 2 },
                       @maxh, curse, stat)
  end
end

# The basic normal mode
module NormodeBase
  public

  def asks(affairs)
    result = 'y' == showmessage(ASKSTC[affairs]).getch
    showmessage('')
    result
  end

  private

  ASKSTC = { quit: 'The note has not been saved yet, do you want to quit?',
             store: 'Do you want to store this notes?',
             delete: 'Do you want to delete this item?',
             tag: 'Do you want to tag / untag this item to a key?',
             add: 'Do you want to add an item?',
             update: 'Do you want to update the bib?'
  }

  INDCSTC = { fileadr: 'Input the file of the item',
              bibadr: 'Input the bibfile of the item',
              bibask: 'Input the bibfile',
              newkey: 'Input the name of the new key',
              modkey: 'Input the new name of the key',
              pkey: 'Choose the parent key',
  }

  def showmessage(msg)
    win = Window.new(1, @scsize[1], @scsize[0] - 1, 0)
    win.attrset(A_BOLD)
    win.addstr(msg)
    win.refresh
    win
  end
end

# The normal mode
class NoteItfBase
  include NormodeBase
  attr_reader :note, :height

  public

  def initialize(notes, height, scsize, labwid, bdspc)
    @height, @scsize, @labwid, @bdspc = height, scsize, labwid, bdspc
    @contwid = labwid - 2 - 2 * bdspc

    @note = Note.new(notes, scsize[0] - @height - 1, @contwid)

    @frmleft = (scsize[1] - labwid) / 2
    @conleft = @frmleft + @bdspc
  end

  def insert(order = -1)
    curs_set(1)

    ins = Insmode.new('', @height, [@scsize[0] - @height - 1, @scsize[1]])
    ins.deal
    @note.ins(ins.file.string, order)

    curs_set(0)
    pagerefresh
  end

  def mod(order)
    curs_set(1)

    ins = Insmode.new(@note.item(order), @height,
                      [@scsize[0] - @height - 1, @scsize[1]])
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

  def store
    @note.store if asks(:store)
  end

  def delete
    @note.delete && pagerefresh if asks(:delete)
  end

  private

  QUITSTC = 'The note has not been saved yet, do you want to quit?'

  def clearpage
    win = Window.new(@scsize[1], @scsize[0], @height, 0)
    win.refresh
    win.close
  end

  def show_note(order = @note.ptr.pst, state = false)
    return if @note.items.empty?
    hegt, alti = @note.ptr.len[order], @note.ptr.location[order] + @height

    frame = state == :picked ? %w(! ~) : %w(| -)
    content = Framewin.new(hegt - 2 , @contwid + 1, alti, @conleft, frame)
    content.framewin.attrset(A_BOLD) if state
    content.framewin.attron(color_pair(6))

    content.cont.addstr(@note.items[order].join("\n"))
    content.refresh
  end
end

# The interface of note
class NoteItf < NoteItfBase
  public

  def initialize(notes, head, scsize, labwid, bdspc)
    super(notes, showhead(head), scsize, labwid, bdspc)
  end

  def deal
    pagerefresh

    loop do
      char = showmessage('').getch
      store if char == 's'
      normdeal(char) || insdeal(char)
      break if char == 'q' && (@note.changed ? asks(:quit) : true)
    end
  end

  private

  HEAD_KEYS = %W(Titile Author identifier)

  def addstring(string, pair = -1, bold = false)
    attrset(A_BOLD) if bold
    attron(color_pair(pair))

    addstr(string)

    attroff(A_BOLD) if bold
    attroff(color_pair(pair))
  end

  def showline(key, content)
    addstring("#{key}: ", 2, true)
    addstring("#{content}\n", 0)
  end

  def showhead(head)
    head[1] = Author.short(head[1])
    setpos(0, 0)
    (0..2).each { |ind| showline(HEAD_KEYS[ind], head[ind]) }
    addstring('^' * cols, 6, true)
    refresh

    headstr = "Title: #{head[0]}\nAuthor: #{head[1]}\nidentifier: #{head[2]}\n"
    Note.new(headstr, lines, cols).items.flatten.size + 1
  end

  def insdeal(char)
    return if @note.items.empty? && char == 'm'
    case char
    when 'a' then insert
    when 'i' then insert(@note.ptr.pst)
    when 'm' then mod(@note.ptr.pst)
    end
  end

  def normdeal(char)
    return if @note.items.empty?
    case char
    when 'd' then delete
    when 'p' then picknote
    when 'j' then move(:d)
    when 'k' then move(:u)
    end
  end
end
