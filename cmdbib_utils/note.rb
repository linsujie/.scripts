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
  include Message

  attr_reader :notes, :items, :ptr, :changed

  public

  def initialize(opt)
    @opt = opt
    @notes = opt[:note]
    @changed = false
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
      action == :delete ? pagediv(order, :focus) : pagediv(order)
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

  def append_core(item, _)
    @items << dealitem(item)
    @ptr.add(@items.last.flatten.size + 2)
  end

  def insert_core(item, order)
    append_core(item, order)
    return if order < 0
    @items[order..-1] = @items[order..-1].rotate!(-1)
  end

  def swap_core(uord, _)
    @items.swapud!(@ptr.pst, uord)
  end

  def delete_core(_, order)
    @items.delete_at(order)
  end

  def cutline(line, width)
    chgl = ->(a, wd, wth) { a.empty? ? true : a[-1].size + wd.size >= wth }

    line.split(' ').each_with_object([]) do |word, page|
      chgl.call(page, word, width) ? page << word : page[-1] << " #{word}"
    end
  end

  def dealitem(item)
    item.sub(/\A\s*/, '@@').split("\n").select { |ln| ln != '' }
      .map { |ln| cutline(ln, @opt[:width]).map { |l| l.sub('@@', '   ') } }
  end

  def pagediv(curse = 0, stat = @ptr.state)
    @ptr = Pointer.new(@items.reduce([]) { |a, e| a << e.flatten.size + 2 },
                       @opt[:nheight], curse, stat)
  end
end

# The normal mode
module NoteItfBase
  include Message
  attr_reader :opt, :note

  public

  def change_item(with_cont = false, act = :insert)
    curs_set(1)

    ins = insmode(with_cont ? @note.item : '')

    ins.deal
    @note.send(act, ins.file.string)

    curs_set(0)
    pagerefresh
  end

  def insmode(string)
    Insmode.new(string, @opt[:height],
                [@opt[:scheight] - @opt[:height] - 1, @opt[:scwidth]])
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
    win = Window.new(@opt[:scheight], @opt[:scwidth], @opt[:height], 0)
    win.refresh
    win.close
  end

  def show_note(order = @note.ptr.pst, state = @note.ptr.state)
    return if @note.items.empty?

    content = getnotewin(order, state)
    showcontent(content, order, state)

    content.refresh
  end

  def showcontent(content, order, state)
    content.framewin.attrset(A_BOLD) if state
    content.framewin.attron(color_pair(6))
    content.cont.addstr(@note.items[order].join("\n"))
  end

  def getnotewin(order, state)
    hegt, alti = getnoteposi(order)
    frame = state == :picked ? %w(! ~) : %w(| -)

    Framewin.new(hegt - 2, @opt[:width], alti, @opt[:labspace], frame)
  end

  def getnoteposi(order)
    [@note.ptr.len[order], @note.ptr.location[order] + @opt[:height]]
  end
end

# The interface of note
class NoteItf
  include NoteItfBase

  public

  DEFOPT = { note: '', title: '', author: '', identifier: '', scheight: 20,
             scwidth: 100, labspace: 2 }
  def initialize(opt = DEFOPT)
    @opt = opt
    DEFOPT.each_key { |k| @opt[k] = DEFOPT[k] unless @opt.key?(k) }

    @opt[:author] = Author.short(@opt[:author])
    formatopt

    @note = Note.new(@opt)
  end

  def deal
    pagerefresh

    loop do
      char = showmessage('').getch
      dealchar(char)
      yield(char) if block_given?
      break if char == 'q' && (@note.changed ? asks(:quit) : true)
    end
  end

  private

  def formatopt
    @opt[:width] = @opt[:scwidth] - 2 - 2 * @opt[:labspace]
    @opt[:height] = showhead
    @opt[:nheight] = @opt[:scheight] - @opt[:height] - 1
  end

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
    "#{key}: #{content}\n"
  end

  def showhead
    setpos(0, 0)
    headstr = %w(title author identifier).map(&:to_sym)
              .reduce('') { |a, e| a + showline(e.upcase, @opt[e]) }
    addstring('^' * cols, 6, true)
    refresh

    countline(headstr)
  end

  def countline(headstr)
    opt = { note: headstr, nheight: lines }
    Note.new(@opt.merge(opt)).items.flatten.size + 1
  end

  STRONG_COMMAND = %w(a i r s)
  COMMANDS = { # bind methods to the keys
    s: :store,
    a: :append,
    i: :insert,
    m: :mod,
    d: :delete,
    p: :picknote,
    r: :pagerefresh,
    '10': [:move, :d],
    '9': [:move, :d],
    j: [:move, :d],
    k: [:move, :u]
  }

  def dealchar(char)
    return if @note.items.empty? && !STRONG_COMMAND.include?(char)

    cmd = COMMANDS[char.to_s.to_sym] || return
    cmd.is_a?(Array) ? send(cmd[0], cmd[1]) : send(cmd)
  end
end
