#!/bin/ruby
# encoding: utf-8
require 'set'
require 'fileutils'

# To analyse a Source file(cc or ruby), and generate the method denpendency
# of it.
class SourceReader
  attr_reader :namelist

  public

  def initialize(filename)
    file = File.new(filename)
    @file = file.reduce([], :<<)
    @cursor = []
    @namelist = { nil => {} }
  end

  def gendpd
    @file.each { |line| get_method_name(line) }
    @keyword = @namelist[nil].each_key.to_set
    @file.each { |line| check_method_depend(line) }
  end

  private

  def rbmethod(line)
    /^\s+def (?<name>\w+)/ =~ line && name.to_sym
  end

  def rbclass(line)
    get_arr = ->(n1, n2) { n2 ? [n1.to_sym, n2.to_sym] : [n1.to_sym] }
    /^\s*class (?<n1>\w+)( < )?(?<n2>\w+)?/ =~ line && get_arr.call(n1, n2)
  end

  def ccmethod(line)
    /^\s*(\w+) (\w+)?(?<name>\w+)\(/ =~ line && name
  end

  def store_class_name(item)
    (@cursor[0], @namelist[item[0]]) = [item, {}]
  end

  def store_method_name(item)
    (@cursor[1], @namelist[@cursor[0][0]][item]) = [item, Set.new]
  end

  def get_method_name(line)
    store_class_name(rbclass(line)) if rbclass(line)
    store_method_name(rbmethod(line)) if rbmethod(line)
  end

  def ch_class_cursor(item)
    @cursor[0] = item
    @keyword = @namelist[nil].merge(@namelist[item[0]])
      .merge(@namelist[item[1]] || {}).each_key.to_set
  end

  def to_reg(hash)
    hash.size == 0 ? /zheshiluanmakdkwo/ : /(#{hash.each_key.to_a.join('|')})/
  end

  def check_method_depend(line)
    return ch_class_cursor(rbclass(line)) if rbclass(line)
    return (@cursor[1] = rbmethod(line)) if rbmethod(line)
    storeline(line)
  end

  def storeline(line)
    stitem = ->(item) { @namelist[@cursor[0][0]][@cursor[1]] << item }
    @keyword.each { |item| stitem.call(item) if /#{item}/ =~ line }
  end
end

# To draw the dependency with dot script
class Drawer
  public

  def initialize(depenlist)
    @depenlist = depenlist
  end

  def plot
    genscript
    `dot -Teps tmp -o function_depend.eps`
    FileUtils.rm('tmp')
  end

  def genscript
    @scrstr = "#!/bin/dot\n\ndigraph G {"
    @depenlist.each { |clas, mthds| write(clas, mthds) }
    @scrstr << '}'
    file = File.new('tmp', 'w')
    file.puts @scrstr
    file.close
  end

  def write(clas, mthds)
    mthds.each do |mthd, others|
      @scrstr << "#{mthd} -> #{clas};\n" if :initialize != mthd
      others.each { |item| @scrstr << "#{item} -> #{mthd};\n" }
    end
  end
end

rb = SourceReader.new(ARGV[0])
rb.gendpd
dr = Drawer.new(rb.namelist)
dr.plot
