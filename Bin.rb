#!/home/linsj/bin/ruby

# Define sum and average method for Array
class Array
  def sum
    reduce(0) { |a, e| a + e }
  end

  def average
    sum.to_f / size.to_f
  end
end

# Provide methods to deal with uncertain dimension array
class Arrays < Array
  def cumula(para, *inds)
    selec = ->(paras) { block_given? ? yield(paras) : paras }
    deal(para, inds) { |a, i, par| a[i] << selec.call(par) }
  end

  def check(*inds)
    opera(0, *inds) { |ele, _| ele }
  end

  def opera(para, *inds)
    selec = ->(ele, paras) { block_given? ? yield(ele, paras) : paras }
    deal(para, inds) { |a, i, par| a[i] = selec.call(a[i], par) }
  end

  def deal(para, *inds)
    tmp = inds.flatten!.shift
    return yield(self, tmp, para) if inds.size == 0
    self[tmp].deal(para, inds) { |arr, ind, par| yield(arr, ind, par) }
  end

  def self.comp?(arr)
    arr.is_a?(Array) && arr.first.is_a?(Array) ? true : false
  end

  def maps(*para)
    para.flatten!
    rec = ->(ary, paras) { ary.maps(paras) { |ele, par| yield(ele, par) } }
    map! { |sub| Arrays.comp?(sub) ? rec.call(sub, para) : yield(sub, para) }
  end
end

# Provide a method to count the distribution of an array
class Bin
  attr_reader :size, :table, :range

  public

  def initialize(lgs, *dimensions)
    @size = dimensions.transpose[2]
    @range = dimensions.reduce([]) { |a, e| a << genrange(lgs, e) }
  end

  def redistribute(array)
    store(array, false, true)
    count { |vals, ind| vals.size * norm(ind) }
  end

  def total(array, withval = false)
    store(array, withval, true)
    count { |vals, ind| vals.size }
  end

  def accept_rate(array, lb, ub)
    t1 = Time.now
    store(array, true, true)
    rate = ->(va) { va.select { |x| x <= ub && x >= lb }.size.to_f / va.size }
    count(true) { |val, _| rate.call(val) }
    t2 = Time.now
    puts t2 - t1
  end

  def print(mod = :list, range1 = 1.0 / 0, range2 = 1.0 / 0)
    mod = :list if @ndimen != 2
    return list if mod == :list
    tab = Table.new(@range, @table, 0)
    tab.print(mod, range1, range2)
  end

  private

  def store(array, withval = false, clear = nil)
    @ndimen = withval ? [*array.first].size - 1 : [*array.first].size
    err = -> { puts 'Error::Bin::store::the array is larger than expected' }
    return err.call if @ndimen > @range.size
    reset(@ndimen) if clear || !@bag
    array.each { |point| stpoint(point, withval) if finds(point, withval) }
  end

  def stpoint(point, withval)
    @num += 1
    @bag.cumula([*point], finds(point, withval))
  end

  def eachs(nd = @range.size, id = 0, index = [])
    return yield(index) if nd == id
    (0..@size[id] - 1).each do |ind|
      index.size <= id ? index << ind : index[index.size - 1] = ind
      eachs(nd, id + 1, index.clone) { |idex| yield(idex) }
    end
  end

  def count(withval = false, nd = @ndimen)
    eachs(nd) do |ind|
      mid = ->(id) { (@range[id][ind[id]] + @range[id][ind[id] + 1]) / 2 }
      getp = -> { (0..ind.size - 1).reduce([]) { |a, e| a << mid.call(e) } }
      calcel = ->(c) { c.reduce([yield(c[0], ind)]) { |a, e| a << e.average } }
      cutval = ->(r) { withval ? r.rotate.pop(r.size - 1).rotate(-1) : r }

      cell = @bag.check(ind).transpose
      res = cell.empty? ? getp.call.unshift(0) : cutval.call(calcel.call(cell))
      @table.opera(res, ind)
    end
  end

  def norm(id)
    lent = ->(ind) { @range[ind].last - @range[ind].first }
    len = ->(ind) { @range[ind][id[ind] + 1] - @range[ind][id[ind]] }

    (0..id.size - 1).reduce(1) { |a, e| a * lent.call(e) / len.call(e) } / @num
  end

  def list
    chgl = ->(ind) { ind % @size[@ndimen - 1] == 0 }
    rowind = 0
    eachs(@ndimen) do |ind|
      puts @table.check(ind).rotate.map { |x| x.round(4) }.join(' ')
      rowind = rowind + 1
      puts '' if chgl.call(rowind)
    end
  end

  def finds(point, withval = false)
    point = [*point].pop(point.size - 1) if withval
    [*point].reduce([]) { |a, e| a << find(e, a.size) }
      .each { |ele| ele < 0 && break }
  end

  def reset(nd = @range.size)
    @num = 0
    @bag = build(nd, [])
    @bag.maps { |ele, _| ele = [] }
    @table = build(nd, [0])
    @table.maps { |ele, _| ele = [0] }
  end

  def build(nd, fill = 0, id = 0)
    return fill if id >= nd
    Arrays.new(@size[id]) { build(nd, fill, id + 1) }
  end

  def genrange(logscale, dimension)
    if logscale
      factor = (dimension[1] / dimension[0])**(1.0 / dimension[2])
      (0..dimension[2]).reduce([dimension[0]]) { |a, e| a << a.last * factor }
    else
      step = (dimension[1] - dimension[0]).to_f / dimension[2]
      (0..dimension[2]).reduce([dimension[0]]) { |a, e| a << a.last + step }
    end
  end

  def find(num, id = 0, lind = 0, hind = @size[id])
    return -1 if num < @range[id].first || num > @range[id].last
    return lind if hind - lind == 1

    mind = (hind + lind) / 2
    recur = ->(ind1, ind2) { find(num, id, ind1, ind2) }
    num >= @range[id][mind] ? recur.call(mind, hind) : recur.call(lind, mind)
  end
end

# provide a method to print 2D arrays
class Table
  public

  def initialize(range, table, col = nil)
    @range =  range
    @table = col ? table.map { |line| line.transpose[col] } : table
  end

  def print(mod = :std, range1 = 1.0 / 0, range2 = 1.0 / 0)
    spl = mod == :std ? '' : '&'
    @style = mod
    headprint(spl)

    axis1 = @range[0].each_cons(2).map { |a, b| (a + b) / 2 }
    (0..axis1.size - 1).each do |ind|
      rangeprint(axis1[ind], spl)
      printvec(@table[ind], spl, range1, range2)
    end

    tailprint
  end

  def rangeprint(cont = nil, splitor = '')
    cont ? printf("%1.2f #{splitor}", cont) : printf(' ' * 5 + splitor)
  end

  def form(splitor = '', color = 0)
    frmtab = { std: ["\e[0m", "\e[1m\e[32m", "\e[1m\e[31m"],\
               latex: ['\color{black}', '\color{blue}', '\color{red}'] }

    frmtab[@style][color] + '%7.3g ' + frmtab[@style][0] + splitor
  end

  def cell(splitor = '', cont = nil, color = 0)
    cont ? sprintf(form(splitor, color), cont) : ' ' * 7 + splitor
  end

  def putlatexhead
    puts <<-eof.gsub(/^\s*/, '')
           \\begin{table}
             \\centering
             \\begin{tabular}{c|*{#{@range[1].size - 1}}{c}}
           eof
  end

  def headprint(splitor)
    putlatexhead if @style == :latex
    printf('%s', cell(splitor))
    printvec(@range[1].each_cons(2).map { |a, b| (a + b) / 2 }, splitor)
    puts '\hline' if @style == :latex
  end

  def tailprint
    puts "\\end{tabular}\n\\end{table}" if @style == :latex
  end

  def colordegree(num, range)
    index = range.size - 1
    index -= 1 while num < range[index]
    index
  end

  def printvec(vector, spl = '', range1 = 1.0 / 0, range2 = 1.0 / 0)
    ran = [0, range1, range2]
    line = vector.reduce([]) { |a, e| a << cell('', e, colordegree(e, ran)) }
    puts line.join(spl)
  end
end
