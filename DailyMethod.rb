#!/usr/local/bin/ruby
# encoding: utf-8

# The module provide the daily used method
module DailyMethod
  def readfile(file, ncol = 2, quickmode = false)
    return unless File.exist?(file)
    arr = File.new(file).read.split(' ')
    return if arr.empty?

    arr.map! { |x| x.to_f } unless quickmode

    arr = arr.each_slice(ncol).to_a
    arr[-1].size == ncol ? arr.transpose : nil
  end
end
