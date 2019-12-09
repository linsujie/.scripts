#!/bin/env ruby
# encoding: utf-8

# The class to supply interpolation methods
class Interp
  attr_reader :available

  public

  # supported type is :lineline :linelog :logline :loglog
  def initialize(x, y, type = :lineline)
    /(?<xtype>line|log)(?<ytype>line|log)/ =~ type.to_s

    raise "Interp::Please specify an exist interpolation type: [lineline, linelog, logline, loglog]" unless xtype && ytype

    raise "Interp::input xvector andd yvector unaligned" unless x.size == y.size

    @x, @y = x, y
    @x.map! { |v| Math.log(v) } if xtype == 'log'
    @y.map! { |v| Math.log(v) } if ytype == 'log'

    @xconv = xtype == 'line' ? ->(v) { v } : ->(v) { Math.log(v) }
    @yconv = ytype == 'line' ? ->(v) { v } : ->(v) { Math.exp(v) }
  end

  def ask(x)
    x = @xconv.call(x)

    index = @x.bsearch_index { |v| v > x }
    iup = [index || (@x.size - 1), 1].max
    ilow = iup - 1

    y = (@y[iup]-@y[ilow]) / (@x[iup]-@x[ilow]) * (x - @x[ilow]) + @y[ilow]

    y = @yconv.call(y)
  end
end
