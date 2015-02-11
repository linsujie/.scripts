#!/usr/bin/ruby -w
# encoding: utf-8

require 'sqlite3'
require 'fileutils'

# This class is some utils to database of bibus
class DbUtils < SQLite3::Database
  public

  BTYPE = %w(article book booklet conference inbook incollection
             inproceedings journal manual)

  def insert(table, keys, val)
    key = "(#{[*keys].join(', ')})"
    qms = "(#{[*keys].map { '?' }.join(', ')})"
    sentence = "insert or replace into #{table} #{key} values #{qms}"
    execute(sentence, val)
  end

  def selects(table, keys, condition, con_val)
    root_select(table, keys, condition, con_val, :abr)
  end

  def nselects(table, keys, condition, con_val)
    root_select(table, keys, condition, con_val, :aba)
  end

  def select(table, keys, condition = [], con_val = [])
    root_select(table, keys, condition, con_val, :exa)
  end

  def update(table, update_pairs, con_pairs)
    keys = update_pairs.to_a.transpose[0].join('=?, ') + '=?'
    condis = con_pairs.to_a.transpose[0].join('=? and ') + '=?'

    execute(
      "update #{table} set #{keys} where #{condis}",
      update_pairs.to_a.transpose[1],
      con_pairs.to_a.transpose[1]
    )
  end

  def deletes(table, condition, con_val)
    delete(table, condition, con_val, true)
  end

  def delete(table, condition, con_val, ambgs = false)
    return if condition.empty?
    condition = cdtjoin(condition, ambgs)
    sentence = "delete from #{table} #{condition}"
    execute(sentence, con_val)
  end

  def addcol(colname)
    type = "text not null on conflict replace default ''"
    sentence = "alter table bibref add column #{colname} #{type}"
    execute(sentence)
  end

  private

  def cdtjoin(condition, ambgs = false, conect = 'and')
    qm = ambgs ? ' like ?' : '=?'
    return '' if [*condition].join(' ') == ''
    'where ' + [*condition].join("#{qm} #{conect} ") + qm
  end

  def root_select(table, keys, condition, con_val, cls)
    ambgs = cls == :aba || cls == :abr
    con_val = [*con_val].map! { |x| "%#{x}%" } if ambgs
    conect = cls == :abr || cls == :exr ? 'or' : 'and'

    keys = [*keys].join(', ')
    condition = cdtjoin(condition, ambgs, conect)

    sentence = "select #{keys} from #{table} #{condition}"

    execute(sentence, con_val)
  end
end

# The class with basic utils to deal with database
class BaseBibUtils
  attr_reader :showkeylist

  public

  def initialize(username, datafile)
    @username = username
    @db = DbUtils.new(datafile)
    gen_colist
    genbibkeylist
  end

  def self.fmtnote(note, mark = '*')
    return '' if note == ''
    "#{mark}  " + note.gsub(/([^\n]\n)([^\n])/, '\1   \2')
       .gsub("\n\n", "\n\n#{mark}  ")
  end

  # EXC_KLS = %W(All References Tagged Query Online Import Cited Trash) << ''
  ANCESTOR = 3

  def genbibkeylist
    list = @db.select(:bibrefkey, %w(key_id parent key_name), :user, @username)
      .map { |id, parent, name| [name.to_sym, [parent, id]] }
      .sort_by { |x| x[0] }
      # .select { |t| !EXC_KLS.include?(t[2]) }

    @bibkeylist = Hash[list]

    list = list.map { |k, v| [k.to_s, v[0], v[1]] }
    pri = list.select { |x| x[1] == ANCESTOR } + list.select { |x| x[2] == ANCESTOR }
    primary = pri.map { |x| [x[0], x[2]] }.transpose
    @showkeylist = showlist(primary, list - pri)
  end

  def showlist(res, ori, gen = 1)
    son = ori.select { |x| res[1].include?(x[1]) }
    son.each { |x| respective_add(res, res[1].index(x[1]) + 1, x, gen) }
    son.empty? ? res : showlist(res, ori - son, gen + 1)
  end

  def respective_add(res, ind, item, gen)
    res[0].insert(ind, '  ' * gen + item[0])
    res[1].insert(ind, item[2])
  end

  def keys(bibid)
    @db.select(:bibreflink, :key_id, :ref_id, bibid).flatten
  end

  def keynames(bibid)
    gkeyn = ->(k) { @db.select(:bibrefkey, :key_name, :key_id, k)[0][0] }

    keys(bibid).reduce([]) { |a, e| a << gkeyn.call(e) }.sort.join(', ') + ' '
  end

  def link_item(keyid, bibid)
    ins = ->(k, b) { @db.insert(:bibreflink, %w(key_id ref_id), [k, b]) }
    del = ->(k, b) { @db.delete(:bibreflink, %w(key_id ref_id), [k, b]) }
    linkexist?(keyid, bibid) ? del.call(keyid, bibid) : ins.call(keyid, bibid)
  end

  def unlink_item(keyid, bibid)
    return :unexist unless linkexist?(keyid, bibid)
    @db.delete(:bibreflink, %w(ref_id key_id), [bibid, keyid])
  end

  private

  DOWN_COL = Hash[[:Id, :Identifier, :BibliographicType, :Address, :Annote, \
                   :Author, :Booktitle, :Chapter, :Edition, :Editor, \
                   :Howpublished, :Institution, :Journal, :Month, :Note, \
                   :Number, :Organizations, :Pages, :Publisher, :School, \
                   :Series, :Title, :Volume, :Year, :URL, \
                   :Custom1, :Custom2, :Custom3, :Custom4, :Custom5, \
                   :Abstract].map { |x| [x, x.downcase] }]

  def fmtcol(col)
    DOWN_COL[col] || col
  end

  def is_y?(str)
    str && (str.upcase == "Y\n" || str.upcase == "YES\n") ? true : false
  end

  def gen_colist
    @colist = @db.select(:sqlite_master, :sql, %w(type name), %w(table bibref))
      .to_s.gsub(/[^(]+\(([^)]+)\).+/, '\1').split(',')
      .reduce([]) { |a, e| a << fmtcol(e.split(' ')[0].to_sym) }
  end

  def get_id
    idlist = @db.select(:bibref, :id, nil, nil).flatten.sort
    ((1..idlist.size + 1).to_a - idlist)[0]
  end

  def sexit(string)
    puts string
    exit
  end

  def linkexist?(keyid, bibid)
    !@db.select(:bibreflink, :key_id, %w(key_id ref_id), [keyid, bibid]).empty?
  end
end

# This class provide methods to deal with keys
# it
class BibusKey < BaseBibUtils
  public

  def dekey(keyname)
    pid, keyid = [*@bibkeylist[keyname.to_sym]] || return
    @db.delete(:bibreflink, :key_id, keyid)
    @db.delete(:bibrefkey, :key_id, keyid)
    adopt(sons(keyid), pid)
  end

  def modkey(keyid, keyname)
    @db.update(:bibrefkey, { key_name: keyname }, key_id: keyid)
    genbibkeylist
  end

  def sons(keyid)
    @bibkeylist.each.select { |k, v| v[0] == keyid }.map! { |x| x[1][1] }
  end

  def offsprings(keyid)
    keyid = [*keyid].map! { |x| x.to_i }
    ofs = keyid.reduce([*keyid]) { |a, e| a << sons(e) }.flatten
    (ofs - keyid).empty? ? ofs : offsprings(ofs)
  end

  def adopt(son, parent)
    parent = [*@bibkeylist[parent.to_sym]][1] || 3 unless parent.is_a?(Integer)
    [*son].each { |x| @db.update(:bibrefkey, { parent: parent }, key_id: x) }
    genbibkeylist
  end

  def branch(key, res = [])
    (parent, _) = @db.select(:bibrefkey, :parent, :key_id, key).flatten
    parent == ANCESTOR ? (res << key)[1..-1] : branch(parent, res << key)
  end

  def addkey(keyname, parent)
    keys = @db.select(:bibrefkey, :key_id).flatten
    newid = ((1..keys.size + 1).to_a - keys)[0]

    @db.insert(:bibrefkey, [:user, :key_id, :parent, :key_name],
               [@username, newid, parent, keyname])
    genbibkeylist
  end
end

# To read information form bibtex file
module BibReader
  attr_reader :bibitems, :bibtype

  # To packaging the detail of reading bibtex file
  class PrivBibReader
    attr_reader :bibitems

    public

    def initialize(tmpfile)
      @bibitems, content = {}, getcontent(File.new(File.expand_path(tmpfile)))
      btype, ident = content.shift.sub(/^@(\w+){(.*),\n$/, '\1 \2').split(' ')
      dowarn(readitems(content))
      bibitem = @bibitems.map { |key, val| [translate(key), val] }

      @bibitems = Hash[bibitem]
      @bibitems.store(:bibliographictype, DbUtils::BTYPE.index(btype.downcase))
      @bibitems.store(:identifier, ident)
      clearname
    end

    private

    TRANSMAP = { adsurl: :url }

    def getcontent(file)
      @swh = false
      file.lines.reduce([]) { |a, e| bibcont?(e) ? a << e : a }
    end

    def bibcont?(line)
      @swh = false if /^}$/ =~ line
      @swh = true if /^@\w+{(?:.+,)?$/ =~ line
      @swh
    end

    def dowarn(sign)
      puts 'Warning::dislocation occuring' if sign == :dislocation
    end

    def translate(key)
      TRANSMAP[key] || key
    end

    def clearname
      @bibitems[:author].gsub!(/[{}]/, '')
    end

    def op_bra(strings)
      braces = { '{' => '}', '(' => ')', '"' => '"' }
      braces = braces.merge(braces.invert)
      strings.reverse.chars.reduce('') { |a, e| a << braces[e] }
    end

    def next_line(content)
      line = content.shift
      line == "\n" ? next_line(content) : line
    end

    def readfirst(content)
      item_first_line = /\s*
        (?<keys>\w+)
        \s*=\s*
        (?<lbrace> "?{? )
        (?<vals>.+)
        /x
      line = next_line(content)
      line ? item_first_line.match(line).to_a[1..-1] : :emptyline
    end

    def readtail(keys, content, ends)
      loop do
        return :itemover if @bibitems[keys].sub!(ends, '')
        line = content.shift || return
        /\s*(?<valtmp>\s.+)/ =~ line && @bibitems[keys] << valtmp
      end
    end

    def readitems(content)
      loop do
        (keys, lbrace, vals) = readfirst(content)
        return :dislocation unless keys
        keys == :emptyline ? return : keys = keys.to_sym
        @bibitems.store(keys, vals) && (ends = /#{op_bra(lbrace)},?\s*\z/)

        return unless readtail(keys, content, ends)
      end
    end
  end

  def readbib(tmpfile)
    system("dos2unix -q #{tmpfile}")
    reader = PrivBibReader.new(tmpfile)
    @bibitems = reader.bibitems
  end
end

# A module to deal with authors' name
module Author
  MAXLEN = 130

  def self.family(namelist)
    fstauthor = namelist.gsub(/and.+$/, '')
    fst = fstauthor.split(',').reverse.map { |x| x.split(' ') }.flatten
    (fst[-2] =~ /(de|De)/ ? "#{fst[-2]} " : '') + fst[-1]
  end

  def self.short(namelist)
    namelist.size > MAXLEN ? family(namelist) + ' et al.' : namelist
  end
end

# This class provide all the methods needed
class Bibus < BibusKey
  attr_reader :db, :username
  include BibReader

  public

  INSIDE_COL = [:note]

  def initialize(username, datafile, refdir = '~/Documents/Reference')
    @refdir = File.expand_path(refdir)
    super(username, File.expand_path(datafile))
  end

  def search(words)
    words.reduce(nil) do |a, e|
      list = @db.selects(:bibref,
                         %w(identifier id author journal volume pages title),
                         %w(title author abstract note eprint volume pages),
                         [e, e, e, e, e, e, e])
      a ? a & list : list
    end
  end

  def addbib(filename, tmpfile = '~/Documents/tmp.bib')
    readbib(tmpfile)
    id, path = get_id, "#{@refdir}/#{@bibitems[:identifier]}.pdf"
    (keylist, valist) = get_updatelist(id)

    @db.insert(:bibref, keylist, valist)
    @db.insert(:file, %w(ref_id path), [id, path])

    link_item(@bibkeylist[:newtmp][1], id)

    addfile(filename, path)
  end

  def debib(bibid, rm_sign = 'no')
    ((bibkey, _)) = @db.select(:bibref, :identifier, :id, bibid)
    path = @refdir + "/#{bibkey}.pdf"
    FileUtils.rm(path) if is_y?(rm_sign) && File.exist?(path)

    @db.delete(:bibref, :id, bibid)
    @db.delete(:bibreflink, :ref_id, bibid)
    @db.delete(:file, :ref_id, bibid)
  end

  def modbib(id, tmpfile = '~/Documents/tmp.bib')
    readbib(tmpfile)

    ((oldbibkey, _)) = @db.select(:bibref, :identifier, :id, id)
    mod_fname(id, oldbibkey, @bibitems[:identifier])

    uplist = get_updatelist(id)
    nullval = (@colist.map { |x| x.downcase } - uplist[0] - INSIDE_COL)
      .map { |x| [x, ''] }

    @db.update(:bibref, nullval + uplist.transpose, id: id)
  end

  def opbib(ident)
    system("(gvfs-open #{@refdir}/#{ident}.pdf &)")
    writelogfile(File.expand_path('~/.opbib_history'), ident)
  end

  def printbibs(idlist, fname, mode = 'a')
    file = File.new(fname, mode)
    idlist.each { |x| printbib(x, file) }
    file.close
  end

  def storenote(bibid, note)
    @db.update(:bibref, { note: note }, id: bibid)
  end

  private

  def mod_fname(id, old, new)
    return  if old == new
    old, new = [old, new].map! { |x| "#{@refdir}/#{x}.pdf" }
    @db.update(:file, { path: new }, ref_id: id)
    FileUtils.mv(old, new) if File.file?(old)
  end

  def printbib(id, file)
    bib = @db.select(:bibref, '*', :id, id)
    return if bib.empty?
    arr = bib.unshift(@colist).transpose.select { |term| term[1][0] }

    _, ident, type = arr.shift(3).transpose[1]
    head = "@#{DbUtils::BTYPE[type]}{#{ident},\n\t"

    mlen = arr.transpose[0].map! { |x| x.size }.max
    str = arr.map! { |term| jointerm(term, mlen) }.join("\n\t") + "\n}\n\n"

    file.puts head + str
  end

  def jointerm(term, mlen)
    term[0].to_s + ' ' * (mlen - term[0].size) + ' = "' + term[1] + '",'
  end

  def writelogfile(filename, item)
    history = File.new(filename).lines.to_a << "#{Time.now} #{item}\n"
    history.shift if history.size >= 1000

    file = File.new(filename, 'w')
    file.puts(history)
    file.close
  end

  def addfile(filename, path)
    return FileUtils.mv(filename, path) if File.file?(filename)
    puts 'file not exist'
  end

  def get_updatelist(id)
    keylist = @bibitems.each_key.reduce([:id], :<<)
    valist = @bibitems.each_value.reduce([id], :<<)

    downcolist = @colist.map { |x| x.downcase }
    reslist = keylist.select { |x| !downcolist.include?(x.downcase) }
    reslist.each { |x| @db.addcol(x) }
    gen_colist unless reslist.empty?

    [keylist, valist]
  end
end
