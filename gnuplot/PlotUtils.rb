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
end
