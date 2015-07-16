#!/usr/local/bin/ruby
# encoding: utf-8

require 'fileutils'
require_relative 'arrayextend.rb'

# To splitting the data with different experiment
class Splitdata
  attr_reader :datlist, :reslist, :extlist, :path

  public

  def initialize(filename, path)
    @file, @path = File.new(filename), path
    @datlist, @reslist, @extlist, @stfiles = {}, {}, {}, []
  end

  def store
    clear(@path)
    loop do
      sign = readline(@stfiles)
      break if sign == :file_end
      grp_change if sign == :data_begin || sign == :grp_begin
      lst_change(sign) if sign == :ext_begin || sign == :rst_begin
    end
    close_file
    [*@empty].each { |file| FileUtils.rm(file) }
    @datlist, @reslist, @extlist = syblz_key([@datlist, @reslist, @extlist])
  end

  def clear(dir)
    rfile = ->(fl) { fl != '.' && fl != '..' }
    Dir.foreach(dir) { |fl| FileUtils.rm("#{@path}/#{fl}") if rfile.call(fl) }
  end

  private

  def lst_change(sign)
    close_file

    list = sign == :rst_begin ? @reslist : @extlist
    @stfiles = [File.new("#{@path}/#{list[@lis_spe].last.join('-')}", 'w+')]
  end

  def grp_change
    close_file

    stfname = @curr_spe + "#{@curr_grp}"
    @stfiles = [File.new("#{@path}/#{stfname}", 'w+')]
  end

  def syblz_key(hashs)
    hashs.map { |ha| Hash[ha.map { |key, val| [key.to_sym, val] }] }
  end

  def close_file
    @stfiles.each { |f| @empty = [*@empty] << f.path if f.tell == 0 }
    @stfiles.each { |file| file.close }
  end

  def readline(*stfiles)
    line = getline || (return :file_end)

    case
    when line.is_a?(String) then return stline(line, stfiles)
    when line[0] == 'Data' then return apend_spe(line[1])
    when line[0] == 'Grp' then return apend_grp(line[1])
    when line[0] =~ /(Result|Extra)/
      return apend_list(line[1..3], line[0])
    end
  end

  def getline
    heads = /\#(?<dr>Data|Result|Extra)\s*
      (?<specy>[^-]+)
      (?:-(?<mlab>[^-]+)-(?<tlab>[^-]+)){0,1}\n
      /x
    grphead = /\#(?<grp>[\w&-]+)\((?<time>[0-9\/-]+)\)$/
    grprsl = proc { |m| ['Grp', "#{m[:grp]}-#{m[:time].gsub('/', '')}"] }
    line = next_line
    return line unless heads =~ line || grphead =~ line
    match = Regexp.last_match
    match.size == 3 ? grprsl.call(match) : match.to_a.pop(4)
  end

  def stline(line, *stfiles)
    stfiles.flatten.each { |sf| sf && sf.is_a?(File) && sf.puts(line) }
    :read_over
  end

  def apend_spe(kind)
    @curr_spe, @curr_grp, @datlist[@curr_spe] = kind, nil, nil
    :data_begin
  end

  def apend_grp(grp)
    @curr_grp, @datlist[@curr_spe] = grp, [*@datlist[@curr_spe]] << grp
    :grp_begin
  end

  def apend_list(row, kind = 'Result')
    list = kind == 'Result' ? @reslist : @extlist
    @lis_spe, list[row[0]] = row[0], [*list[row[0]]] << row[0..2]
    kind == 'Result' ? :rst_begin : :ext_begin
  end

  def @file.gets
    @point = tell
    gets
  end

  def next_line
    excreg = /(#(?!Result|Data|Extra|[\w&-]+\([0-9\/-]+\)$)|^$)/
    loop do
      tmpline = @file.gets
      break tmpline unless excreg =~ tmpline
    end
  end

  def ftime(fullname)
    File.new(fullname).ctime.to_i
  end
end

# To splitting the data with different experiment
class SplitData
  attr_reader :list, :path

  public

  def initialize(filename, path = nil)
    @file, @path = File.new(filename).each.reject { |l| is_anno?(l) }, path

    @list = getlist
  end

  def store(path = @path)
    @path = path
    raise RangeError, 'No path to store' unless @path
    Dir.glob("#{@path}/*").each { |x| FileUtils.rm(x) }
    savelist
  end

  def SplitData.formfname(fname)
    fname.gsub('/', '').gsub('(', '-').gsub(')', '')
  end

  private

  def getlist
    heads = @file.each_with_index.select { |l, i| is_head?(l) }.transpose
    heads = heads[0].zip(heads[1].push(@file.size).each_cons(2).to_a)
    Hash[slicing(heads, /#Data /).map { |k, v| [k, Hash[getarr(v)]] }]
  end

  def getarr(val)
    k = ->(s) { %r{^#(?<kd>Result|Extra)} =~ s ? kd.downcase.to_sym : :data }
    dealrdc = ->(a, e) { a[k.call(e[0])].store(*readf(e)) and a }

    val.reduce({result: {}, data: {}, extra: {}}) { |a, e| dealrdc.call(a, e) }
  end

  def readf(term)
    [term[0].chomp.gsub(/^#(Result|Extra)?\s?/, ''),
     formatdat(term[1][0] + 1, term[1][1] - 1)]
  end

  def formatdat(stline, endline)
    exits =->(i) { puts("Something wrong in data::#{@file[i-5..i+5].join('')}"); exit(0) }
    tidejudge = ->(a, e) { a[-1] && a[-1].size != e.size }
    insert = ->(a, e, i) { tidejudge.call(a, e) ? exits.call(i) : a << e }

    deale = ->(i) { @file[i].split(' ') }

    (stline..endline).reduce([]) { |a, e| insert.call(a, deale.call(e), e) }
    .transpose
  end

  def slicing(array, reg)
    genkey = ->(term) { term[0][0].chomp.sub(reg, '').to_sym }

    array.each_with_index.select { |term, ind| reg =~ term[0] }
    .push([nil, 0]).each_cons(2)
    .map { |t, n| [genkey.call(t), array[t[1] + 1..n[1] - 1]] }
    .reduce({}) { |a, e| a[e[0]] ? a[e[0]] += e[1] : a[e[0]] = e[1]; a }
  end

  HEAD_REG = /^#(Data|Result|[\w&-]+\(+[0-9\/-]+\)|Extra)/
  SKIP_REG = /^#\tE\t/
  def is_anno?(l)
    l[0] == '#' and not (HEAD_REG =~ l)
  end

  def is_head?(l)
    HEAD_REG =~ l
  end

  def savelist
    @list.each { |k, v| v.each { |_, sps| savespecs(k, sps) } } #v.each { |kind, sps| savespecs(kind, specs) } }
  end

  def savespecs(kind, specs)
    specs.each { |n, spec| save("#{kind}#{n}", spec) }
  end

  def save(fname, spec)
    return unless @path
    FileUtils.mkdir_p(@path)
    file = File.new("#{@path}/#{SplitData.formfname(fname)}", 'w')
    file.puts spec.transpose.map! { |t| t.join(' ') }
    file.close
  end
end
