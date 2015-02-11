#!/home/linsj/bin/ruby
# encoding: utf-8

# To ask the precise paths for certain prefix and postfix (and maybe a given
# order of the task)
class DirAsk
  attr_reader :path, :file, :tail

  class << self
    attr_accessor :date
  end

  def initialize(prefix, postfix, chosen = nil)
    @recdat, @prefix, @postfix = File.expand_path('~/recdat'), prefix, postfix
    @prefix, @postfix = lists unless @prefix || @postfix

    @chosen = chosen

    @path = obtain_path
    obtain_sub_paths
  end

  TIMEFMT = /\d{2}[.]\d{2}-\d{2}:\d{2}/

  private

  def shows(str)
    puts str
    str
  end

  def add_base(str)
    str && "#{@recdat}/#{str}"
  end

  def obtain_path
    (ch = getchoice.sort).empty? && ch = getchoice.sort
    return shows(add_base(ch[@chosen - 1])) if @chosen && ch[@chosen - 1]

    ch.size > 1 ? askchoice(ch) : add_base(ch[0])
  end

  def obtain_sub_paths
    self.class.date = @path ? @path.sub(/.+(#{TIMEFMT})\w*/, '\1') : nil
    @tail = @path ? @path.sub(/.+\/(\w+)#{self.class.date}\w*/, '\1') : nil
    @file = @path ? gendetails : {}
  end

  def gendetails
    h = { like: "#{@path}/out/*.likestats", marg: "#{@path}/out/*.margestats",\
          cov: "#{@path}/out/*.covmat", ini: "#{@path}/inifile/distgalp*.ini" }
      .map { |k, v| [k, Dir.glob(v)[0]] }
    Hash[h]
  end

  def drag(name)
    /^(?<head>\w+)\d{2}[.]\d{2}-\d{2}:\d{2}(?<tail>\w*)/ =~ name
    [head, tail]
  end

  def lists
    arr = Dir.foreach(@recdat).map { |n| drag(n) }.uniq
           .reject { |x| x == [nil, nil] }.sort_by { |x| x.reverse.join('') }
    $stderr.puts 'choose one task you want'
    $stderr.puts formatjoin(arr, 5)
    arr[$stdin.gets.to_i -  1]
  end

  def formatjoin(arr, num = 5)
    ' ' + arr.each_with_index.map { |x, ind| formats(x, ind, num) }.join(' ')
  end

  def formats(str, ind, num = 5)
    fixx = ->(x) { x.is_a?(Array) ? x[0].ljust(8) + x[1] : x }
    fixi = ->(i) { "\e[1m#{i + 1}.\e[0m".ljust(11) }
    form = ->(x, i) { "#{fixi.call(i)} #{fixx.call(x)}".ljust(138 / num + 8) }
    form.call(str, ind) + ((ind + 1) % num == 0 ? "\n" : '')
  end

  def getchoice
    return [] unless @prefix || @postfix
    @postfix ||= /\w+/
    regexp = /#{@prefix}#{self.class.date || TIMEFMT}#{@postfix}$/
    self.class.date &&= nil
    Dir.foreach(@recdat).select { |item| regexp =~ item }
  end

  def askchoice(list)
    $stderr.puts "\e[1mThere's several choices, which one do you want? "\
      + "input a number or 'q'\n#{formatjoin(list, 4)}\e[0m"
    ch = $stdin.gets.chomp
    'q' == ch ? nil : "#{@recdat}/#{list[ch.to_i - 1]}"
  end
end
