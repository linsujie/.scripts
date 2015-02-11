#!/usr/bin/ruby
# encoding: utf-8

require File.expand_path('../frame.rb', __FILE__)

# The basic utils for menu
module MenuUtils
  attr_reader :curse, :scurse, :list

  public

  def setctrl(qkey, dkey, ukey)
    @qkey, @dkey, @ukey = qkey, dkey, ukey
  end

  def set(curse, scurse, list = @list)
    @list = list[0].is_a?(Array) ? list : [list]
    @curse, @scurse = curse, scurse
    @contlen = @list[0].size < @maxlen ? @list[0].size : @maxlen
    @win.each { |win| win.cont.clear }
    mrefresh
  end

  def setcol(visible, mainm = @mainm)
    @visible, @mainm = visible, mainm
  end

  def current(col = @mainm)
    @list[col] ? @list[col][@curse % listsize].to_s : nil
  end

  private

  def pitem(col, ind)
    pointstr(col, @list[col][ind % listsize].to_s, ind - @scurse)
  end

  def colrefresh(col)
    @win[col].freshframe
    (@scurse..@scurse + @contlen - 1).each { |ind| pitem(col, ind) }

    @win[col].cont.refresh
    frefresh(col)
  end

  def pointstr(col, strs, line)
    pair = @visible[col]
    @win[col].cont.attron(color_pair(pair)) if pair != true
    @win[col].cont.setpos(line, 0)
    @win[col].cont.addstr(fillstr(strs, col))
    @win[col].cont.attroff(color_pair(pair)) if pair != true
  end

  def theta(x)
    x > 0 ? x : 0
  end

  def fillstr(str, col = @mainm)
    str + ' ' * theta(@width[col] - str.size)
  end

  def frefresh(col)
    @win[col].cont.attron(A_STANDOUT)
    pointstr(col, current(col), @curse - @scurse)
    @win[col].cont.attroff(A_STANDOUT)
    @win[col].cont.refresh
  end

  def listsize
    @list[0].size == 0 ? 1 : @list[0].size
  end

  def cursedown
    @curse += 1
    @scurse += 1 if @scurse == @curse - @maxlen
  end

  def curseup
    @curse -= 1
    @scurse -= 1 if @scurse == @curse + 1
  end

  def jumphead
    (@curse, @scurse) = [0, 0]
  end

  def jumptail
    (@curse, @scurse) = [@list[0].size - 1, @list[0].size - @contlen]
  end
end

# Creating a menu
class Menu
  include MenuUtils
  attr_reader :win, :curse, :scurse

  public

  def initialize(list, posi, length = [20, false], width = nil, mainm = 0, frame = false)
    @list = list[0].is_a?(Array) ? list : [list]
    ininumbers(posi, length, width, mainm)

    cw = ->(e) { Framewin.new(@maxlen, @width[e], @lsft, @csft[e] + 1, frame) }
    @win = (0..@csft.size - 1).reduce([]) { |a, e| a << cw.call(e) }
    @win.each { |win| win.cont.keypad(true) }

    @qkey, @dkey, @ukey = ['q', ' ', 10], ['j', KEY_DOWN, 9], ['k', KEY_UP]
  end

  def get
    curs_set(0)

    loop do
      char = mrefresh.getch
      deal(char)
      break if @qkey.include?(char)
    end
    current
  end

  def mrefresh
    @visible
      .each_with_index { |bool, ind| colrefresh(ind) if bool && @list[ind] }
    @win[@mainm].cont
  end

  def to_a
    @list[@mainm]
  end

  private

  def ininumbers(posi, length, width, mainm)
    @lsft, @csft = posi.is_a?(Fixnum) ? [posi, [0]] : [posi[0], posi[1..-1]]
    @csft.map { |x| x + 1 }
    (mlen, fix) = [*length] << false

    @contlen = @list[0].size < mlen ? @list[0].size : mlen
    @maxlen = fix ? mlen : @contlen

    @curse, @scurse, @mainm, @visible = 0, 0, mainm, @csft.map { true }

    lastw = width || @list[0].map { |x| x.size }.max + 1
    @width = @csft.each_cons(2).map { |pvs, nxt| nxt - pvs - 1 } << lastw
  end

  def deal(char)
    return if @list[0].empty?

    eolist = @curse == @list[0].size - 1

    case true
    when @dkey.include?(char) then eolist ? jumphead : cursedown
    when @ukey.include?(char) then @curse == 0 ? jumptail : curseup
    end
  end
end

# The advance menu that support extra dealing
class AdvMenu < Menu
  attr_reader :char
  attr_accessor :curse, :scurse

  def get(ind = @mainm)
    curs_set(0)

    loop do
      @char = mrefresh.getch
      deal(@char)
      yield(self, @char) if block_given? && @char.is_a?(String)
      break if @qkey.include?(@char)
    end
    current(ind)
  end
end
