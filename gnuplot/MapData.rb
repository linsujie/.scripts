#!/home/linsj/bin/ruby
# encoding: utf-8

require File.expand_path('../PlotUtils.rb', __FILE__)
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

  def plot_contour(fname)
    Gnuplot.open do |gp|
      Gnuplot::SPlot.new(gp) do |plot|
        plot.unset('surface')
        plot.set('contour')
        plot.cntrparam("level discrete #{@contval.join(', ')}")
        plot.table(%Q("#{fname}"))

        plot.data = [
          Gnuplot::DataSet.new(@cols) do |ds|
            ds.with = "lines"
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
    filex, filey = ['x', 'y'].map { |f| File.new(fname + f, 'w') }

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

  def formatline(vector)
    vector.map { |x| format("%.5e", x) }.join(' ')
  end

  def readarrayfile(files)
    content = readdata(files[0])
    x, y = files[1..2].map { |fn| readdata(fn).transpose[0] }

    readarray([content, x, y])
  end

  def readarray(datas)
    @array, @xaxis, @yaxis = datas
    @xsize, @ysize = @xaxis.size, @yaxis.size

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
    @xaxis, @yaxis = @cols[0].uniq.compact, @cols[1].uniq.compact
    @xsize, @ysize = @xaxis.size, @yaxis.size

    return puts(INCOLWARN) unless @cols[2].compact.size == @xsize * @ysize
    @array =  @cols[2].compact.each_slice(@ysize).to_a.transpose
  end

  def getcols
    nilterm = [nil, nil, nil]
    col = ->(i) { [@xaxis[i[0]], @yaxis[i[1]], @array[i[1]][i[0]]] }

    @cols = (0..@xsize - 1).to_a.product((0..@ysize).to_a)
    .reduce([]) { |a, e| a << (e[1] == @ysize ? nilterm : col.call(e)) }[0..-2]
    .transpose
  end
end
