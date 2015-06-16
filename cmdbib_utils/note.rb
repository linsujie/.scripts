#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'message.rb'
require_relative 'insert.rb'
require_relative 'pointer.rb'
require 'curses'

include Curses

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

  def item(order = @ptr.pst)
    @items[order].map { |line| line.join(' ') }.join("\n")
  end

  def change_notes(order, focus = nil)
    @changed = true
    yield(p1, order)
    focus ? pagediv(order, focus) : pagediv(order, focus)
  end

  [:mod, :append, :insert, :swap, :delete].each do |action|
    define_method(action) do |item = '', order = @ptr.pst|
      @changed = true
      send("#{action}_core", item, order)
      action == :delete ?  pagediv(order, :focus) : pagediv(order)
    end
  end

  def store
    @changed = false
    @notes = (0..@items.size - 1)
      .reduce([]) { |a, e| a << item(e) }.join("\n\n")
  end

  private

  def mod_core(item, order)
    @items[order] = dealitem(item)
  end

  def append_core(item, order)
    @items << dealitem(item)
    @ptr.add(@items.last.flatten.size + 2)
  end

  def insert_core(item, order)
    append_core(item, order)
    return if order < 0
    @items[order..-1] = @items[order..-1].rotate!(-1)
  end

  def swap_core(uord, order)
    @items.swapud!(@ptr.pst, uord)
  end

  def delete_core(item, order)
    @items.delete_at(order)
  end

  def cutline(line, width)
    chgl = ->(a, wd, wth) { a.empty? ? true : a[-1].size + wd.size >= wth }

    line.split(' ').reduce([]) do |a, e|
      chgl.call(a, e, width) ? a << e : a[-1] << " #{e}"
      a
    end
  end

  def dealitem(item)
    item.sub(/\A\s*/, '@@').split("\n").select { |ln| ln != '' }
      .map { |ln| cutline(ln, @maxw).map { |l| l.sub('@@', '   ') } }
  end

  include Message
  def pagediv(curse = 0, stat = @ptr.state)
    @ptr = Pointer.new(@items.reduce([]) { |a, e| a << e.flatten.size + 2 },
                       @maxh, curse, stat)
  end
end

# The normal mode
module NoteItfBase
  include Message
  attr_reader :note, :height

  public

  def change_item(with_cont = false, act = :insert)
    curs_set(1)

    string = with_cont ? @note.item : ''
    ins = Insmode.new(string, @height, [@scsize[0] - @height - 1, @scsize[1]])
    ins.deal
    @note.send(act, ins.file.string)

    curs_set(0)
    pagerefresh
  end

  [[:insert, false], [:append, false], [:mod, true]].each do |func, cont|
    define_method(func) { send(:change_item, cont, func) }
  end

  def picknote
    @note.ptr.chgstat
    show_note(@note.ptr.pst)
  end

  def move(uord)
    @note.swap(uord) if @note.ptr.state == :picked

    show_note(@note.ptr.pst, false)
    (uord == :u ? @note.ptr.down : @note.ptr.up) && pagerefresh
    show_note
  end

  def store
    @note.store if asks(:store)
  end

  def delete
    @note.delete && pagerefresh if asks(:delete)
  end

  private

  QUITSTC = 'The note has not been saved yet, do you want to quit?'

  def pagerefresh
    clearpage
    @note.ptr.page(@note.ptr.pst) { |ind| show_note(ind, false) }
    show_note
  end

  def clearpage
    win = Window.new(@scsize[0], @scsize[1], @height, 0)
    win.refresh
    win.close
  end

  def show_note(order = @note.ptr.pst, state = @note.ptr.state)
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
class NoteItf
  include NoteItfBase

  public

  def initialize(notes, head, scsize, labwid, bdspc)
    @height, @scsize, @labwid, @bdspc = showhead(head), scsize, labwid, bdspc
    @contwid = labwid - 2 - 2 * bdspc

    @note = Note.new(notes, scsize[0] - @height - 1, @contwid)

    @frmleft = (scsize[1] - labwid) / 2
    @conleft = @frmleft + @bdspc
  end

  def deal
    pagerefresh

    loop do
      char = showmessage('').getch
      store if char == 's'
      dealchar(char)
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

  STRONG_COMMAND = %w(a i r)
  COMMANDS = { # bind methods to the keys
    a: :append,
    i: :insert,
    m: :mod,
    d: :delete,
    p: :picknote,
    r: :pagerefresh,
    j: [:move, :d],
    k: [:move, :u]\
  }

  def dealchar(char)
    return if @note.items.empty? && !STRONG_COMMAND.include?(char)

    cmd = COMMANDS[char.to_sym] || return
    cmd.is_a?(Array) ? send(cmd[0], cmd[1]) : send(cmd)
  end
end
