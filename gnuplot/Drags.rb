#!/home/linsj/bin/ruby
# encoding: utf-8

require 'benchmark'
require '~/.scripts/DailyMethod.rb'
require 'pathname'
# Drag the exclude line information from data
class Drags
  include DailyMethod
  attr_reader :datas, :line, :linedash, :path, :ts, :info, :sym, :stat, :errfile

  def initialize(path, bound, anti = false, update = false, ignore_bad = false)
    @stat = :old
    pr, an = setini(path, bound, anti)
    return(@stat = :nodata) unless File.exist?(path)
    return unless update || !readdata(path)
    @stat = :refresh

    @line, @ts, @ignore, @errfile = [[], []], [[], []], ignore_bad, []
    Dir.foreach(pr).select { |x| x !~ /^\./ }
      .sort_by { |x| x.to_f }.each { |n| drag("#{pr}/#{n}", n, anti) }

    #Dir.foreach(an).select { |x| x !~ /^\./ }
    #  .sort_by { |x| x.to_f }.each { |n| getts("#{an}/#{n}", n, anti) }

    dealline if @line[0][0]
    #joints == :sizediff ? @stat = :fail : record
  end

  private

  def record
    line = File.new("#{path}/line", 'w')
    line.puts @line.transpose.map { |l| l.join(' ') }
    line.close

    ts = File.new("#{path}/ts", 'w')
    ts.puts @ts.transpose.map { |l| l.join(' ') }
    ts.close
  end

  def readdata(path)
      @line, @ts = ["#{path}/line", "#{path}/ts"].map { |f| readfile(f) }
      @cursv = MAXSV
      dealline if @line
      [@line, @ts].reduce(true) { |a, e| a && e }
  end

  MAXSV = 1e-16
  def dealline
    mark = @line[1].each_cons(2)
    .map { |f, s| f < 0.94 * MAXSV && s < 0.94 * MAXSV && f / s < 8 }
    .reduce([]) { |a, e| a << (a[-1] || e) } << true

    tmp = @line.transpose.zip(mark)
    stval = tmp.find { |_, m| m }[0][1]

    @linedash = tmp.select { |_, m| !m }.map { |x, _| [x[0], stval] }.transpose
    @line = tmp.select { |_, m| m }.map { |x, _| x }.transpose

    #@line[1].each { |x| tmpdeal if x < 1e-27 }
  end

  INFOMAP = { eleven: :I, thirteen: :II, ams: :III }
  def transinfos(word)
    INFOMAP[word.to_sym] || word.to_sym
  end

  def setini(path, bound, anti)
    puts "Reading from #{path}"

    arr = path.split('/').map { |x| transinfos(x) }
    arr.delete_at(0)
    arr.delete_at(1)

    @info = Hash[[[:dir], arr].transpose]
    @sym = arr.join('_')

    @path, @bound, @tsp, @tsa, @datas = path, bound.to_f, [], [], [[], [], []]

    anti ? ["#{path}/anti", "#{path}/pro"] : ["#{path}", "#{path}/anti"]
  end

  def joints
    mchi, posi = @tsp.transpose
    _, nega = @tsa.transpose

    sizediff = "#{@path}::pro data have different size with anti data"

    if !mchi || posi.size != nega.size
      exit(puts(sizediff)) unless @ignore
      puts("IGNORING:: #{sizediff}")
      return(:sizediff)
    end

    @ts = [mchi, posi, nega]
      .transpose.map { |mc, ts1, ts2| [mc, ts1 + ts2 > 0 ? ts1 : ts2] }
      .transpose
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
    when 'r' then FileUtils.rm(file)
    when 'c'
      puts File.new(file).each.to_a[-4..-1]
      dealwrongfile(file)
    when 'i' then return :return
    end
    exit 1
  end

  def getts(file, mchi, anti)
    return(deallargefile(file)) if File.size(file) > 1000000
    arr = readfile(file, 3, true) #File.new(file).each.map { |l| l.split(' ').map { |x| x.to_f } }
    return unless arr
    chi = arr[2].map! { |x| x.to_f }

    stachi, minchi = chi[0], chi.min
    tstmp, prod = anti ? [@tsp, 1] : [@tsa, -1]
    tstmp << [mchi.to_f, prod * Math.sqrt(stachi - minchi)]
  end

  def drag(file, mchi, anti)
    puts "Reading #{file}"
    return(deallargefile(file)) if File.size(file) > 1000000

    arr = readfile(file, 3, true)
    dealwrongfile(file) && return unless arr
    arr[2].map! { |x| x.to_f }

    stachi, minchi = arr[2][0], arr[2].min
    arr[2].map! { |x| x - minchi }

    tstmp, prod = anti ? [@tsa, -1] : [@tsp, 1]
    tstmp << [mchi.to_f, prod * Math.sqrt(stachi - minchi)]

    keyline = arr.transpose.reverse.find { |x| x[2] < @bound }
    .each_with_index.map { |x, i| (anti ? (-1)**ind : 1) * x.to_f }

    (0..1).each { |ind| @line[ind] << keyline[ind] }

    (0..2).each { |ind| @datas[ind] += arr[ind] + [nil] }
  end
end
