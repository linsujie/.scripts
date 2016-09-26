#!/usr/env ruby
# encoding: utf-8

require 'json'
require 'rainbow/ext/string'
require 'timeout'
require_relative 'table'

# The sys function as an extention of system, with timeout support
def sys(str, log = nil)
  puts [str, log && log.color(:yellow)].compact.join(' > ')

  cmd = [str, log].compact.join(' > ')

  pid = Process.spawn(cmd)
  begin
    Timeout::timeout(TIMELIMIT) do
      Process.wait(pid)
    end
  rescue Timeout::Error
    puts "command out of time, re-Run".bright
    system("pkill -TERM -P #{pid}")
    sys(str, log)
  end
end

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

  MP = 0.938272 # in unit of GeV
  def rg2ekn(rg, a, z)
    momentn = rg * z / a
    Math.sqrt(MP * MP + momentn * momentn) - MP
  end

  def ekn2rg(ekn, a, z)
    momentn = Math.sqrt(ekn * ekn + 2 * ekn * MP)
    momentn * a / z
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

  def upper_bound(x)
    return :up_over if x >= self[-1]
    return :low_over if x < self[0]

    dichotomy(x)[1]
  end

  def lower_bound(x)
    return :up_over if x >= self[-1]
    return :low_over if x < self[0]

    dichotomy(x)[0]
  end

  def average
    reduce(0.0, &:+) / size
  end

  private

  def dichotomy(x)
    l, u = 0, size - 1
    while(u - l > 1)
      mid = (u + l) / 2
      self[mid] > x ? u = mid : l = mid
    end
    [l, u]
  end
end

module JSON
  def self.latex_table(json, ele_width = 20, transpose = false)
    table = to_table(json)

    table.transpose! if transpose

    isplit = (0..table.line_size - 1).to_a.reverse
      .find { |il| table.max_width(il) > 1 }

    if isplit
      (0..table.col_size - 1).select { |ic| table.main_ele?(isplit, ic) }[2..-1]
      .reverse.each { |ic| table.insert_col(ic) }
    end

    table.latex_str(ele_width)
  end

  def self.to_table(json)
    array = table_array(json).transpose

    table = Table.new

    array[0..-2].each_with_index do |line, iline|
      line.each_with_index do |ele, icol|
        ele == :to_fuse ? table.combine_left(iline, icol) : table[iline, icol] = ele
      end
    end

    lhead = table.line_size
    lkeys = array[-1].reduce([]) { |a, e| a | e.keys }

    lkeys.each_with_index do |key, il|
      array[-1].each_with_index do |val, icol|
        table[lhead + il, icol] = val[key] || '----'
      end
    end

    table.unshift_col([nil] * lhead + lkeys)

    table
  end

  def self.table_array(json)
    array = []
    json_to_array(array, json, [])

    table_size = array.map(&:size).max
    array.each { |l| (table_size - l.size).times { l.insert(-2, nil) } }
    array
  end

  private_class_method def self.json_to_array(array, json, prekey)
    return array << (prekey << json) unless json[json.keys[0]].is_a?(Hash)

    first_key = true

    json.to_a.sort_by { |k, _| k }.each do |k, subjson|
      pre = first_key ? (prekey + [k]) : (prekey.map { :to_fuse } + [k])
      json_to_array(array, subjson, pre)

      first_key = false
    end
  end
end
