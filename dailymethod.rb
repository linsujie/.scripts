#!/usr/env ruby
# encoding: utf-8

# The module provide the daily used method
module DailyMethod
  def readfile(file, ncol = 2, quickmode = false)
    return unless File.exist?(file)
    arr = File.new(file).read.split(' ')
    return if arr.empty?

    arr.map!(&:to_f) unless quickmode

    arr = arr.each_slice(ncol).to_a
    arr[-1].size == ncol ? arr.transpose : nil
  end

  MP = 0.938272 # in unit of GEV
  def rgn2ekn(rgn, z)
    momentn = rgn * z
    Math.sqrt(MP * MP + momentn * momentn) - MP
  end

  def ekn2rgn(ekn, z)
    Math.sqrt(ekn * ekn + 2 * ekn * MP) / z
  end
end

# Extend the Array class
class Array
  SPLITOR_MAP = ["\t", "\n", "\n\n", '']

  def to_page(ind = level_number - 1)
    map { |x| x.is_a?(Array) ? x.to_page(ind - 1) : x }
      .join(SPLITOR_MAP[ind])
  end

  def level_number
    map { |x| x.is_a?(Array) ? x.level_number + 1 : 1 }.max || 0
  end

  def average
    reduce(0.0, &:+) / size
  end
end