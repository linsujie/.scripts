#!/home/linsj/bin/ruby
# encoding: utf-8

require_relative 'plotutils.rb'
# Dealwith the two dimension datas in format:
#        x0 y0 value00
#        x0 y1 value01
#        ......
#
#        x1 y0 value10
#        ......
# or
#            - x ->
#     |  v00 v10 v20 ...
#     y  v01 v11 v21 ...
#     |  ...              , together with the vector_x and vector_y
class MapData
  include PlotUtils
  attr_reader :cols, :array, :xaxis, :yaxis, :xsize, :ysize, :contval

  public

  def initialize(inputed, kind = :array)
    send("read#{kind}", inputed)
  end

  def setcontour(contval)
    @contval = contval
  end

  def setpowscale(label = :x)
    @xaxis.map! { |x| 10**x } if [:x, :xy].include?(label)
    @yaxis.map! { |y| 10**y } if [:y, :xy].include?(label)

    getcols
  end

  def setlogscale(label = :x)
    @xaxis.map! { |x| Math.log10(x) } if [:x, :xy].include?(label)
    @yaxis.map! { |y| Math.log10(y) } if [:y, :xy].include?(label)

    getcols
  end

  def rescale(label = [:x, :y], factor = [1, 1])
    [*label].zip([*factor]).each { |l, f| rescale_axis(l, f) }
    getcols
  end

  def plot_contour(fname)
    Gnuplot.open do |gp|
      Gnuplot::SPlot.new(gp) do |plot|
        plot.unset('surface')
        plot.set('contour')
        plot.cntrparam("level discrete #{@contval.join(', ')}")
        plot.table(%("#{fname}"))

        plot.data = [
          Gnuplot::DataSet.new(@cols) do |ds|
            ds.with = 'lines'
            ds.title = ''
          end
        ]
      end
    end
  end

  def printcols(fname)
    file = File.new(fname, 'w')
    file.puts @cols.transpose.map { |t| formatline(t) }
    file.close
  end

  def printarray(fname)
    file = File.new(fname, 'w')
    filex, filey = %w(x y).map { |f| File.new(fname + f, 'w') }

    file.puts @array.map { |t| formatline(t) }
    filex.puts formatline(@xaxis)
    filey.puts formatline(@yaxis)

    file.close
    filex.close
    filey.close
  end

  private

  INWARN = 'MapData::Warning::inappropriate inputed '
  INARRWARN = INWARN + 'array'
  INCOLWARN = INWARN + 'cols'

  def rescale_axis(label = :x, factor = 1)
    case label
    when :x then @xaxis.map! { |x| x * factor }
    when :y then @yaxis.map! { |y| y * factor }
    end
  end

  def formatline(vector)
    return if vector == [nil, nil, nil]
    vector.map { |x| format('%.5e', x) }.join(' ')
  end

  def readarrayfile(files)
    content = readdata(files[0])
    x, y = files[1..2].map { |fname| readaxis(fname) }

    readarray([content, x, y])
  end

  def readaxis(fname)
    dat = readdata(fname)
    dat.size == 1 ? dat.flatten : dat.transpose[0]
  end

  def readarray(datas)
    @array, @xaxis, @yaxis = datas
    @xsize = @xaxis.size
    @ysize = @yaxis.size

    yfit = @array.size == @ysize

    lsizes = @array.map { |l| l && l.size }.compact.uniq
    xfit = lsizes.size == 1 && lsizes[0] == @xsize

    return puts(INARRWARN) unless @array && @xaxis && @yaxis && xfit && yfit

    getcols
  end

  def readcolsfile(file)
    @cols = readdata(file).map { |t| t.empty? ? [nil, nil, nil] : t }.transpose
    readcols
  end

  def readcols(cols = @cols)
    @cols = cols
    @xaxis = @cols[0].uniq.compact
    @yaxis = @cols[1].uniq.compact
    @xsize = @xaxis.size
    @ysize = @yaxis.size

    return puts(INCOLWARN) unless @cols[2].compact.size == @xsize * @ysize

    format_cols unless @cols[2].size == @xsize * (@ysize + 1) - 1
    @array =  @cols[2].compact.each_slice(@ysize).to_a.transpose
  end

  def format_cols
    @cols.map!(&:compact)

    ins = ->(c, i) { c.insert(@xsize * @ysize - @ysize * i, nil) }
    @cols.map! { |c| (1..@xsize - 1).each { |i| ins.call(c, i) } && c }
  end

  def getcols
    nilterm = [nil, nil, nil]
    cvcore = ->(ix, iy) { [@xaxis[ix], @yaxis[iy], @array[iy][ix]] }
    colvals = ->(ix, iy) { iy == @ysize ? nilterm : cvcore.call(ix, iy) }

    @cols = (0..@xsize - 1).to_a.product((0..@ysize).to_a)
            .reduce([]) { |a, e| a << colvals.call(e[0], e[1]) }[0..-2]
            .transpose
  end
end
