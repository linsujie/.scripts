#!/home/linsj/bin/ruby
# encoding: utf-8
require 'gnuplot'

require '~/.scripts/interp.rb'

# A class to keep a range between lots of spectra
class Range
  attr_reader :min, :max, :x

  FILL = 'filledcurves fs transparent solid 0.5 '

  def initialize(positive = true)
    @min = nil
    @max = nil
    @positive = positive
    @x = nil
  end

  def input(arr)
    arr.map! { |term| term.map!(&:to_f) }
    intp = Interp.new(arr[0], arr[1])
    ytmp = @x.map { |x| intp.lnask(x) }
    inputy(ytmp)
  end

  def inputy(vec)
    vec = vec.map(&:to_f)
    @min, @max = [vec] * 2 if !@min || !@max

    @min = @min.zip(vec).map { |x| @positive ? [x.min, 1e-300].max : x.min }
    @max = @max.zip(vec).map { |x| @positive ? [x.max, 1e-300].max : x.max }
  end

  def inputx(vec)
    @x = vec.map(&:to_f)
  end

  def print(filename)
    File.new(filename, 'w').puts @x.zip(@min, @max).map! { |l| l.join(' ') }
  end

  def to_ds(label = :normal)
    return unless @x && block_given?

    xaxis = @x + @x.reverse
    yaxis = @min + @max.reverse
    arr = label == :transpose ? [yaxis, xaxis] : [xaxis, yaxis]
    Gnuplot::DataSet.new(arr) { |ds| yield(ds) }
  end
end
