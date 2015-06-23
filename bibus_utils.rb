#!/usr/bin/env ruby
# encoding: utf-8

require 'sqlite3'
require 'fileutils'
require_relative 'foldlist.rb'

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

  TEXTFORM = "TEXT NOT NULL ON CONFLICT REPLACE DEFAULT ''"
  def addcol(colname)
    sentence = "alter table bibref add column #{colname} #{TEXTFORM}"
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
module BaseBibUtils
  attr_reader :biblist

  public

  def self.fmtnote(note, mark = '*')
    return '' if note == ''
    "#{mark}  " + note.gsub(/([^\n]\n)([^\n])/, '\1   \2')
       .gsub("\n\n", "\n\n#{mark}  ")
  end

  def genbiblist
    l = @db.select(:bibrefkey, %w(key_id parent key_name), :user,
                   @opts[:username])
    @biblist = FoldList.new(l, @opts[:ancestor])
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
      .to_s.gsub(/\\n/, '').gsub(/[^(]+\(([^)]+)\).+/, '\1').split(',')
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
module BibusKey
  public

  def dekey(kinfo)
    item = @biblist.tree.find(kinfo.is_a?(Integer) ? :id : :keyname, kinfo)

    @db.delete(:bibreflink, :key_id, item.id)
    @db.delete(:bibrefkey, :key_id, item.id)
    adopt(item.children.map(&:id), item.parent)
  end

  def modkey(keyid, keyname)
    @db.update(:bibrefkey, { key_name: keyname }, key_id: keyid)
    genbiblist
  end

  def sons(keyid)
    @bibkeylist.each.select { |k, v| v[0] == keyid }.map! { |x| x[1][1] }
  end

  def adopt(son, parent)
    item_p = @biblist.tree.find(parent.is_a?(Integer) ? :id : :keyname, parent)
    parent = item_p ? item_p.id : @opts[:ancestor]
    [*son].select { |x| x.to_i != parent.to_i }
      .each { |x| @db.update(:bibrefkey, { parent: parent }, key_id: x) }
    genbiblist
  end

  def addkey(keyname, parent)
    keys = @db.select(:bibrefkey, :key_id).flatten
    newid = ((1..keys.size + 1).to_a - keys)[0]

    @db.insert(:bibrefkey, [:user, :key_id, :parent, :key_name],
               [@opts[:username], newid, parent, keyname])
    genbiblist
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
class Bibus
  attr_reader :db, :opts, :username, :ancestor, :reader
  include BaseBibUtils
  include BibusKey
  include BibReader

  public

  INSIDE_COL = [:note]

  DEFOPTS = { username: :user, datafile: 'user.db', reader: 'gvfs-open',
              refdir: '~/Documents/Reference', ancestor: 1 }
  def initialize(options = DEFOPTS)
    @opts = options
    DEFOPTS.each_key { |k| @opts.key?(k) or @opts[k] = DEFOPTS[k] }
    @opts[:refdir] = File.expand_path(@opts[:refdir])

    nulldb = !File.exist?(File.expand_path(@opts[:datafile]))
    @db = DbUtils.new(File.expand_path(@opts[:datafile]))
    gendb if nulldb

    gen_colist
    genbiblist
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
    id = get_id
    (keylist, valist) = get_updatelist(id)

    @db.insert(:bibref, keylist, valist)
    @db.insert(:file, %w(ref_id path), [id, filepath(@bibitems[:identifier])])

    link_item(@biblist.tree.find(:keyname, 'newtmp').id, id)

    addfile(filename, @bibitems[:identifier])
  end

  def debib(bibid, rm_sign = 'no')
    ((bibkey, _)) = @db.select(:bibref, :identifier, :id, bibid)
    is_y?(rm_sign) and File.exist?(filepath(bibkey)) and
      FileUtils.rm(filepath(bibkey))

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
    system("(#{@opts[:reader]} #{filepath(ident)} &)")
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

  def addfile(filename, ident)
    return FileUtils.mv(filename, filepath(ident)) if File.file?(filename)
    puts 'file not exist'
  end

  private

  BIBREFCOLS = %w(Address Annote Author Booktitle Chapter Edition Editor Howpublished Institution Journal Month Note Number Organizations Pages Publisher School Series Title Report_Type Volume Year URL Custom1 Custom2 Custom3 Custom4 Custom5 ISBN Abstract Doi eprint archivePrefix primaryClass SLACcitation reportNumber keywords adsnote collaboration)
  def gendb
    @db.execute(<<-eof
  CREATE TABLE bibref  (Id INTEGER PRIMARY KEY, Identifier TEXT UNIQUE,
    BibliographicType INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
    #{BIBREFCOLS.map { |x| "#{x} #{DbUtils::TEXTFORM}" }.join(', ')});
  eof
          )

    @db.execute("CREATE TABLE bibrefKey  (user #{DbUtils::TEXTFORM}, key_Id INTEGER PRIMARY KEY, parent INTEGER, key_name TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'newkey');")
    @db.execute("CREATE TABLE bibrefLink  (key_Id INTEGER,ref_Id INTEGER,UNIQUE (key_Id,ref_Id));")
    @db.execute("CREATE TABLE bibquery  (query_id INTEGER PRIMARY KEY,user #{DbUtils::TEXTFORM},name TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'query',query #{DbUtils::TEXTFORM});")
    @db.execute("CREATE TABLE table_modif (ref_Id INTEGER,creator #{DbUtils::TEXTFORM},date REAL NOT NULL ON CONFLICT REPLACE DEFAULT 0,user_modif TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',date_modif REAL NOT NULL ON CONFLICT REPLACE DEFAULT 0,UNIQUE (ref_Id));")
    @db.execute("CREATE TABLE file  (ref_Id INTEGER, path TEXT NOT NULL);")
    @db.insert(:bibrefkey, %w(user key_Id key_name), [@opts[:username], @opts[:ancestor], 'Reference'])
    @db.insert(:bibrefkey, %w(user key_Id parent key_name), [@opts[:username], @opts[:ancestor] + 1, @opts[:ancestor], 'newtmp'])
  end

  def filepath(ident)
    "#{@opts[:refdir]}/#{ident}.pdf"
  end

  def mod_fname(id, old, new)
    return  if old == new
    old, new = [old, new].map! { |x| filepath(x) }
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
