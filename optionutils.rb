#!/home/linsj/bin/ruby
# This class provides methods to deal with options in linux command line
ArgvBase = Struct.new(:shlist, :lglist, :dflist, :slmap, :transmap) do

  public

  def deal(argv)
    argv || return
    @accept = false
    @focus = false

    argv.each do |term|
      getarg(term)
      check(term)
    end
    mapping
    lglist.each_key { |key| format(key) }
    translate
  end

  def getarg(term)
    @accept && term !~ /-\w+/ && setval(@focus, term)
    @accept = false
  end

  def check(term)
    /--(?<lgop>\w+)/ =~ term && (return getlgoption(lgop))
    /-(?<shop>\w+)/ =~ term && getshoption(shop)
  end

  def getlgoption(option)
    settrue(option.to_sym)
    @focus = option.to_sym
    @accept = :long
  end

  def getshoption(options)
    options.each_char
      .reduce([]) { |a, e| /[0-9]/ =~ e ? a.last << e && a : a << e }
      .each { |option| settrue(option.to_sym) }
    @focus = options.each_char.first.to_sym
    @accept = :short
  end

  def level(opt)
    return 0 if sllist(opt).nil?
    return 1 if sllist(opt) == false || sllist(opt) == true
    2
  end

  def prio?(shopt, lgopt)
    level(shopt) >= level(lgopt)
  end

  def sllist(option)
    String(option).size == 1 ? shlist[option] : lglist[option]
  end

  def slasg(option, term)
    String(option).size == 1 ? shlist[option] = term : lglist[option] = term
  end

  def setval(option, term)
    level(option) > 0 && slasg(option, term)
  end

  def settrue(*options)
    options.each { |opt| level(opt) <= 1 && slasg(opt, true) }
  end

  def setfalse(option)
    level(option) > 0 && slasg(option, false)
  end

  def mapping
    slmap.each do |sop, lop|
      prio?(sop, lop) ? lglist[lop] = shlist[sop] : shlist[sop] = lglist[lop]
    end
  end

  def only(*paras)
    saved = paras.each { |key| break key if lglist[key] }
    saved = saved.is_a?(Array) ? paras.last : saved
    paras.each { |key| key == saved ? settrue(key) : setfalse(key) }
  end

  def splopt(key, tonum)
    lglist[key] = lglist[key].split(',').map { |x| tonum ? x.to_f : x.to_sym }
  end

  def format(key)
    return if level(key) < 2 || !lglist[key].is_a?(String)
    /[a-zA-Z]/ !~ lglist[key] ? splopt(key, true) : splopt(key, false)
    lglist[key].size == 1 && lglist[key] = lglist[key][0]
  end

  def getdfval(key_)
    hasval = ->(key) { dflist[key].select { |k| lglist[k] }.values[0] }
    lglist[key_] = dflist[key_].is_a?(Hash) ? hasval.call(key_) : dflist[key_]
  end

  def setdf
    dflist.each_key { |key| lglist[key] == true && getdfval(key) }
  end

  def translate
    totrans = ->(key) { level(key) == 2 && lglist[key].size == 1 }
    trans = ->(key) { lglist[key] = transmap[key][lglist[key]] }
    transmap.each_key { |key| totrans.call(key) && trans.call(key) }
  end
end
