#!/usr/bin/env ruby
# encoding: utf-8

# The pointer about where should the note item print, and which is the current
# item
class Pointer
  attr_reader :segment, :location, :len, :pst, :state

  public

  def initialize(array, segsize, pst, state)
    warn = ->() { puts 'Warning:: There is an item too long' }
    warn.call if !array.empty? && segsize < array.max
    @segsize, @len, @state = segsize, array, state
    @pst = pst >= array.size - 1 ? array.size - 1 : pst
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
    return if @len.empty?
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
