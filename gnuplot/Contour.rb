#!/home/linsj/bin/ruby
# encoding: utf-8

require File.expand_path('../PlotUtils.rb', __FILE__)

# To generate Gnuplot::Daataset for Contour files
class Contour
  include PlotUtils
  attr_reader :ds

  def initialize(fname, ls)
    data = readdata(fname).reduce({}) { |a, e| insertterm(a, e) }
    ls = ls.map { |k, v| v.map { |i| [k, i] } }.transpose.map { |l| Hash[l] }

    @ds = data.zip(ls).map { |h, l| get_ds(h[1].transpose[0..1], l) }
  end

  private

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
