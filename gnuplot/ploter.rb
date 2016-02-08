#!/usr/bin/env ruby
# encoding: utf-8
require 'gnuplot'

class Ploter

  DEFAULT_OPT = { output: 'tmp.eps', xlabel: 'E_{kin}(GeV/nuleon)',
                  ylabel: 'E^{2.7}dN/dE(GeV^{1.7}m^{-2}s^{-1}sr^{-1})',
                  tb: :bottom, lr: :right
  }
  def initialize(opt)
    @opt = opt
    DEFAULT_OPT.each_key { |k| @opt[k] = DEFAULT_OPT[k] unless @opt.key?(k) }

    Gnuplot.open do |gp|
      gp << %Q(set terminal epscairo enhanced color dashed size 5.5, 4 font 'Helvatica,18' dl 2) << "\n"
      gp << %Q(set output "#{@opt[:output]}") << "\n"

      Gnuplot::Plot.new(gp) do |plot|
        plot.xtics 'in format "10^{%T}"'
        plot.ytics 'in format "10^{%T}"'
        originplotini(plot)
        yield(plot)
      end
    end
  end


  DIREC = { left: 'Left reverse', right: 'Right noreverse' }
  def originplotini(plot)
    plot.xlabel @opt[:xlabel]
    plot.ylabel @opt[:ylabel]

    plot.key "#{@opt[:tb]} #{@opt[:lr]} #{DIREC[@opt[:lr]]} spacing 1.2 samplen 3 height 0.2"
  end
end
