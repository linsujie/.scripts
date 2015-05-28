#!/home/linsj/bin/ruby
# encoding: utf-8

require File.expand_path('../PlotUtils.rb', __FILE__)
require File.expand_path('../../DailyMethod.rb', __FILE__)

# To generate Gnuplot::Daataset for Contour files
#
# The input information could be filename or array.
#
# If the cont_val is nil, the inputed infomation would be treated as Contour
# info, or as Table data on the other hand.
#
# All the inputed data should be arranged in the three-column format, a 2-d
# table together with xaxis and yaxis could be transformed to this form with
# the class MapData
#
# inputed ls is a hash in format { lt: [1, 2], lc: [2, 3], lw: [3, 3] }
class Contour
  include PlotUtils
  attr_reader :ds

  def initialize(fname, ls, cont_val = nil)
    dealinput(fname, cont_val)

    ls = ls.to_a.map { |k, v| v.map { |i| [k, i] } }.transpose
      .map { |l| Hash[l] }

    @ds = @contarray.zip(ls).map { |h, l| get_ds(h[1].transpose[0..1], l) if l }
      .compact
  end

  private

  def dealinput(fname, cont_val)
    @array = fname.is_a?(Array) && fname

    defaultfile = %w(tmptable.dat conttmptable.dat)
    @fname, @contfname = @array ? defaultfile : [fname, "cont_#{fname}"]

    @contarray =
      if cont_val
        @array ||= readdata(@fname).map { |x| x.empty? ? [nil] * 3 : x }
        .transpose

        gen_contour(cont_val, @array)
      else
        @array || readcontour(@fname)
      end
  end

  def gen_contour(cont_val, arr)
    Gnuplot.open do |gp|
        Gnuplot::SPlot.new(gp) do |plot|
          plot.unset('surface')
          plot.set('contour')
          plot.cntrparam("level discrete #{cont_val.join(',')}")
          plot.table(%Q("#{@contfname}"))

          plot.data = [ Gnuplot::DataSet.new(arr) { |ds| ds.with = "lines" }]
        end
    end
    readcontour(@contfname)
  end

  def readcontour(contname)
    readdata(contname).reduce({}) { |a, e| insertterm(a, e) }
  end

  def insertterm(array, term)
    if term.empty?
      array[@curind] << [nil, nil, nil] unless array.empty? || !array[@curind][-1][0]
    else
      @curind = term[2]
      array[@curind] ||= []
      array[@curind] << term
    end

    array
  end
end
