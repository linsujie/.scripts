#!/home/linsj/bin/ruby
# encoding: utf-8

require 'pathname'
require_relative 'plotutils.rb'
require_relative '../dailymethod.rb'

# To generate Gnuplot::DataSet for Contour files
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
  attr_accessor :contarray

  def initialize(fname, ls, cont_val = nil)
    dealinput(fname, cont_val)

    @ls = ls.to_a.map { |k, v| v.map { |i| [k, i] } }.transpose
      .map { |l| Hash[l] }
  end

  def ds
    @contarray.to_a.zip(@ls)
      .map { |h, l| get_ds(h[1].transpose[0..1], l) if l }.compact
  end

  private

  def dealinput(inputed, cont_val)
    send(inputed.is_a?(Array) ? :inputarray : :inputfname, inputed, cont_val)
  end

  def inputfname(file, cont_val)
    fname = Pathname.new(file)
    contname = fname.parent + "cont_#{fname.basename}"

    rarr = ->() { inputarray(readdata(fname).transpose, cont_val, contname) }
    @contarray = cont_val ? rarr.call : readcontour(fname)
  end

  def inputarray(array, cont_val, contname = 'cont_tmptable.dat')
    cont_val ? gen_contour(cont_val, array, contname) : array
  end

  def readcontour(contname)
    readdata(contname, :plain).reduce({}) { |a, e| insertterm(a, e) }
  end

  def gen_contour(cont_val, arr, contname)
    Gnuplot.open do |gp|
      Gnuplot::SPlot.new(gp) do |plot|
        plot.unset('surface')
        plot.set('contour base')
        plot.cntrparam("level discrete #{cont_val.join(',')}")
        plot.table(%Q("#{contname}"))

        plot.data = [Gnuplot::DataSet.new(arr) { |ds| ds.with = "lines" }]
      end
    end
    readcontour(contname)
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
