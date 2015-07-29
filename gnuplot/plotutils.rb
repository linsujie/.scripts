#!/home/linsj/bin/ruby
# encoding: utf-8

require 'gnuplot'

# Some util methods for gnuplot
module PlotUtils
  def readdata(fname)
    result = inputfile(fname).map { |l| l.split(' ').map(&:to_f) }
    size = result.map(&:size).max
    result.map { |l| l.empty? ? [nil] * size : l }
  end

  def get_ds(array, ls, title = '')
    Gnuplot::DataSet.new(array) do |ds|
      ls = [:lt, :lc, :lw].map { |x| "#{x} #{ls[x]} " if ls[x] }.join(' ')
      ds.with = 'lines ' + ls
      ds.title = "#{title}"
    end
  end

  def readexpdata(fname)
    inputfile(fname, /(^#\s*$|^\s*$)/).unshift("\n").join('')
      .split("\n#")[1..-1]
      .each_with_object({}) { |e, a| a.store(*group2pair(e)) }
  end

  private

  def inputfile(fname, reject_reg = /^#/)
    File.new(File.expand_path(fname)).each.reject { |l| reject_reg =~ l }
  end

  def group2pair(gstr)
    garr = gstr.split("\n")
    [garr[0], garr[1..-1].map { |l| l.split(' ') }.transpose]
  end
end
