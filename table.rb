#!/usr/env ruby
# encoding: utf-8

# A class to store an manipulate the information of a table
class Table
  attr_reader :col_size, :line_size

  def initialize
    @content = []
    @col_size = 0
    @line_size = 0
  end

  %w(push unshift).each do |action|
    define_method("#{action}_line") do |vec|
      @content.send(action, (0..@col_size - 1).map { |i| element(vec[i]) })
      @line_size += 1
    end

    define_method("#{action}_col") do |vec|
      (0..@line_size - 1).each do |i|
        @content[i].send(action, element(vec[i]))
      end
      @col_size += 1
    end
  end

  def insert_line(iline, vec = [])
    @content.insert(iline, (0..@col_size - 1).map { |i| element(vec[i].to_s) })
    (0..@col_size - 1).each do |icol|
      combine_up(iline, icol) unless up_ele?(iline + 1, icol)
    end
    @line_size += 1
  end

  def insert_col(icol, vec = [])
    (0..@line_size - 1).each do |iline|
      @content[iline].insert(icol, element(vec[iline].to_s))
      combine_left(iline, icol) unless left_ele?(iline, icol + 1)
    end
    @col_size += 1
  end


  %w(pop shift).each do |action|
    define_method("#{action}_line") do
      @content.send(action)
      @line_size -= 1
    end

    define_method("#{action}_col") do
      (0..@line_size - 1).each { |i| @content[i].send(action) }
      @col_size -= 1
    end
  end

  def combine_up(iline, icol)
    return if iline == 0
    refresh_line(iline)
    refresh_col(icol)

    target = self[iline - 1, icol]
    iline_main, icol_main = iline - 1 - target[:vshift], icol - target[:shift]

    self[iline_main, icol_main][:vsize] += 1

    refresh_large_element(iline_main, icol_main)
  end

  def combine_left(iline, icol)
    return if icol == 0
    refresh_line(iline)
    refresh_col(icol)

    target = self[iline, icol - 1]
    iline_main, icol_main = iline - target[:vshift], icol - 1 - target[:shift]

    self[iline_main, icol_main][:size] += 1

    refresh_large_element(iline_main, icol_main)
  end

  def []=(iline, icol, string)
    refresh_line(iline)
    refresh_col(icol)

    @content[iline][icol][:string] = string
  end

  def [](iline, icol)
    @content[iline] && @content[iline][icol]
  end

  def max_width(iline)
    (0..@col_size - 1).map { |ic| self[iline, ic][:size] }.max
  end

  def max_height(icol)
    (0..@line_size - 1).map { |il| self[il, icol][:vsize] }.max
  end

  def string(iline, icol)
    return self[iline, icol][:string] if main_ele?(iline, icol)
    medium = self[iline, icol]

    self[iline - medium[:vshift], icol - medium[:shift]][:string]
  end

  def main_ele?(iline, icol)
    self[iline, icol][:string] != :ref_main
  end

  def left_ele?(iline, icol)
    self[iline, icol][:shift] == 0
  end

  def up_ele?(iline, icol)
    self[iline, icol][:vshift] == 0
  end

  private

  def refresh_large_element(iline, icol)
    e = self[iline, icol]

    (0..e[:vsize] - 1).to_a.product((0..e[:size] - 1).to_a).each do |il, ic|
      next if il == 0 && ic == 0
      obj = self[iline + il, icol + ic]
      obj[:string] = :ref_main
      [:vsize, :size].each { |k| obj[k] = e[k] }
      obj[:vshift] = il
      obj[:shift] = ic
    end
  end

  def element(str = nil)
    { string: str, vsize: 1, size: 1, vshift: 0, shift: 0 }
  end

  def refresh_line(iline)
    return if iline < @line_size
    (@line_size..iline).each do |i|
      @content[i] = []
      @col_size.times { @content[i].push(element) }
    end
    @line_size = iline + 1
  end

  def refresh_col(icol)
    return if icol < @col_size
    (0..@line_size - 1).each do |i|
      (icol - @col_size + 1).times { @content[i].push(element) }
    end
    @col_size = icol + 1
  end
end
