#!/home/linsj/bin/ruby
# encoding: utf-8

require 'gnuplot'

# Some util methods for gnuplot
module PlotUtils
  def readdata(fname)
    File.new(File.expand_path(fname)).each.select { |l| /^#/ !~ l }
    .map { |l| l.split(' ').map { |x| x.to_f } }
  end

  def get_ds(array, ls)
    Gnuplot::DataSet.new(array) do |ds|
      ds.with = "lines " \
        + [:lt, :lc, :lw].map { |x| "#{x} #{ls[x]} " if ls[x] }.join(' ')
      ds.title = ''
    end
  end

  def readexpdata(fname)
    File.new(File.expand_path(fname)).each.reject { |l| /(^#\s*$|^\s*$)/ =~ l }
    .unshift("\n").join('').split("\n#")[1..-1]
    .reduce({}) { |a, e| a.store(*group2pair(e)) and a }
  end

  private

  def group2pair(gstr)
    garr = gstr.split("\n")
    [garr[0], garr[1..-1].map { |l| l.split(' ') }.transpose]
  end
end
