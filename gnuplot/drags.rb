#!/home/linsj/bin/ruby
# encoding: utf-8

require 'fileutils'
require 'pathname'
require_relative 'dailymethod.rb'

# Drag the exclude line information from data
class Drags
  include DailyMethod
  attr_reader :datas, :line, :linedash, :path, :ts, :stat, :errfile

  def initialize(path, bound = 3.84146, update = false, outpath = nil)
    @stat, @outpath = :old, outpath || File.expand_path('..', path)
    return unless update || !readdata
    return(@stat = :nodata) unless File.exist?(path)

    @stat, @bound = :refresh, bound

    @line, @ts, @datas, @errfile = [[], []], [[], []], [[], [], []], []

    Dir.glob("#{path}/*").sort_by { |x| x.sub(%r{#{path}/}, '').to_f }
      .each { |file| drag(file) }

    smooth_start if @line[0][0]
  end

  def record
    FileUtils.mkdir_p @outpath
    File.new("#{@outpath}/line", 'w').puts @line.transpose.to_page
    File.new("#{@outpath}/linedash", 'w').puts @linedash.transpose.to_page
    File.new("#{@outpath}/ts", 'w').puts @ts.transpose.to_page
  end

  private

  def readdata
    @line, @ts, @linedash = %w(line ts linedash).map { |x| "#{@outpath}/#{x}" }
      .map { |f| readfile(f) }

    smooth_start if @line
    [@line, @ts, @linedash].reduce(true) { |a, e| a && e }
  end

  MAXSV = 1e-16
  def smooth_start
    mark = @line[1].each_cons(2)
    .map { |f, s| f < 0.94 * MAXSV && s < 0.94 * MAXSV && f / s < 8 }
    .reduce([]) { |a, e| a << (a[-1] || e) } << true

    tmp = @line.transpose.zip(mark)
    stval = tmp.find { |_, m| m }[0][1]

    @linedash = tmp.select { |_, m| !m }.map { |x, _| [x[0], stval] }.transpose
    @line = tmp.select { |_, m| m }.map { |x, _| x }.transpose
  end

  def deallargefile(file)
    puts("File too large::#{file}, delete it")
    FileUtils.rm(file)
  end

  def dealwrongfile(file)
    puts <<-eof
    File #{file} is incomplete, what do you want to do with it.
      (r)emove    (c)heck     (i)gnore
    eof
    case $stdin.gets.chomp
    when 'r' then return(FileUtils.rm(file))
    when 'c'
      puts File.new(file).each.to_a[-4..-1]
      dealwrongfile(file)
    when 'i' then return(@errfile << file)
    end
  end

  def drag(file)
    puts "Reading #{file}"
    return(deallargefile(file)) if File.size(file) > 1000000

    arr = readfile(file, 3, true)
    dealwrongfile(file) && return unless arr
    arr[2].map!(&:to_f)

    stachi, minchi = arr[2][0], arr[2].min
    arr[2].map! { |x| x - minchi }

    keyline = arr.transpose.reverse.find { |x| x[2] < @bound }.map(&:to_f)
    tsnum = [keyline[0], Math.sqrt(stachi - minchi)]

    (0..1).each { |ind| @line[ind] << keyline[ind] }
    (0..1).each { |ind| @ts[ind] << tsnum[ind] }

    (0..2).each { |ind| @datas[ind] += arr[ind] + [nil] }
  end
end
