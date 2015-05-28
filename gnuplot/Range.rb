#!/home/linsj/bin/ruby
require 'gnuplot'

require '~/.scripts/interp.rb'

# A class to keep a range between lots of spectra
class Range
  attr_reader :min, :max, :x

  FILL = 'filledcurves fs transparent solid 0.5 '

  def initialize
    @min, @max, @x = nil, nil, nil
  end

  def input(arr)
    arr.map! { |term| term.map! { |n| n.to_f } }
    intp = Interp.new(arr[0], arr[1])
    ytmp = @x.map { |x| intp.linask(x) }
    inputy(ytmp)
  end

  def inputy(vec)
    vec = vec.map { |x| x.to_f }
    @min, @max = vec, vec if !@min || !@max

    @min = @min.zip(vec).map { |x|  [x.min, 1e-300].max }
    @max = @max.zip(vec).map { |x| [x.max, 1e-300].max }
  end

  def inputx(vec)
    @x = vec.map { |x| x.to_f }
  end

  def to_ds(label = :normal)
    return unless @x && block_given?

    xaxis, yaxis = @x + @x.reverse, @min + @max.reverse
    arr = label == :transpose ? [yaxis, xaxis] : [xaxis, yaxis]
    Gnuplot::DataSet.new(arr) { |ds| yield(ds) }
  end
end
