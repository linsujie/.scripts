#!/usr/bin/ruby
# encoding: utf-8

require File.expand_path('../note.rb', __FILE__)

# The utils for cmdbib, including the logic for all the substantial
# multipulations
CmdBibBase = Struct.new(:bib) do

  TMPFILE = File.expand_path('~/Documents/tmp.bib')

  private

  def search(word)
    return [] if word == ''
    bib.search(word.split(' '))
      .map { |item| [item[0], bib.keynames(item[1]), item[6], item[1]] }
      .transpose
  end

  def listall
    whole_list = bib.db.select(:bibref, %w(identifier id title))
      .map { |x| [x[0], bib.keynames(x[1]), x[2], x[1]] }.sort_by { |x| x[3] }
      .transpose
    @list.set(0, 0, whole_list)
  end

  def listidents(idents)
    table = bib.db.selects(:bibref, %w(identifier id title),
                           idents.map { 'identifier' }, idents)
      .map { |item| [item[0], bib.keynames(item[1]), item[2], item[1]] }
    idents.map { |x| table.find { |term| term[0] == x } }
      .select { |x| x }.transpose
  end

  def obtainlist(list)
    list.map { |x| bib.db.select(:bibref, %w(identifier id title), :id, x) }
      .select { |x| x[0] }
      .map { |it, _| [it[0], bib.keynames(it[1]), it[2], it[1]] }.transpose
  end

  def keyidents(keyid)
    obtainlist(bib.db.select(:bibreflink, :ref_id, :key_id, keyid).flatten)
  end

  def listrefresh
    @list.set(@list.curse, @list.scurse, obtainlist(@list.to_a))
  end

  JNLHASH = { '\prd' => 'PRD', '\apj' => 'ApJ', '\jcap' => 'JCAP',
              '\apjl' => 'ApJL', '\mnras' => 'MNRAS',
              '\aap' =>  'Astron.Astrophys.' }

  def gcont(id)
    a = bib.db.select(:bibref, %w(title author id journal volume pages eprint
                                  note), :id, id).flatten

    return [] unless a[3..5]
    [a[0], Author.short(a[1].to_s), bib.keynames(a[2]),
     (JNLHASH[a[3]] || a[3]).sub(/([^.])$/, '\1 ') + a[4..5].join(' '),
     a[6], a[7]]
  end

  def refreshpanel(listref = true)
    listrefresh if listref
    clear
    refresh
    showc
    @list.mrefresh
  end

  def update
    return  unless asks(:update)

    bibname = diag_with_msg(:file, :bibask)
    return if bibname == ''

    bib.modbib(@list.current, bibname)
    back_bibfile(bibname)
  end

  def add
    return unless asks(:add)

    filename = diag_with_msg(:file, :fileadr)
    bibname = diag_with_msg(:file, :bibadr)

    return if filename == '' || bibname == ''

    bib.addbib(filename, bibname)
    back_bibfile(bibname)
  end

  def diag_with_msg(comp_type, msg_type)
    showmessage(NormodeBase::INDCSTC[msg_type])
    result = listdiag(comp_type, NormodeBase::INDCSTC[msg_type])
    showmessage('')
    result
  end

  def back_bibfile(bibname)
    bibname = File.expand_path(bibname)
    FileUtils.mv(bibname, TMPFILE) unless bibname == TMPFILE
  end

  def tag_current
    listmenu(tlist) { |k| bib.link_item(k, @list.current) } if asks(:tag)
  end

  def tlist
    ltb = bib.keys(@list.current)
    #showmessage(ltb.to_s).getch
    lform = ->(x) { ltb.include?(x[1]) ? '* ' + x[0] : '  ' + x[0] }
    bib.showkeylist.transpose.map! { |x| [lform.call(x), x[1]] }.transpose
  end

  def delete
    bib.debib(@list.current, "y\n") if asks(:delete)
  end

  def cstat
    @stat = @stat == :content ? :list : :content
    visible = @stat == :content ? [7, nil, nil, nil] : [7, 5, true, false]
    @list.setcol(visible)
  end

  def noting
    return if @list.current == ''
    clear
    ((author, title, notes)) = bib.db
      .select(:bibref, %w(author title note), :id, @list.current)

    head = [title, author, @list.current(0)]
    pad = NoteItf.new(notes, head, @scsize, @scsize[1], 1)

    pad.deal
    bib.storenote(@list.current, pad.note.notes)
    refreshpanel(false)
  end

  def listhistory
    identlist = File.new(File.expand_path('~/.opbib_history')).each
      .map { |line| line.split(' ')[-1] }.reverse.uniq[0..29]
    @list.set(0, 0, listidents(identlist))
  end

  def listdiag(comps = false, bgstrs = '')
    @diag.reset
    @diag.complist = comps

    @diag.deal do
      refreshpanel(false)
      showmessage(bgstrs)
    end

    yed = ->(str) { str == '' ? str : yield(str) }
    block_given? ? yed.call(@diag.file.string) : @diag.file.string
  end

  def listmenu(list, ctrl = false, curses = [0, 0], v_order = 1)
    menu = @menu.clone
    menu.set(curses[0], curses[1], list)
    choice = menu.get(v_order)  { |menu, char| keycontrol(menu, char) if ctrl }
    return if menu.char == 'q'

    yield(choice)
  end

  def listkeys
    listmenu(bib.showkeylist, true) { |key| @list.set(0, 0, keyidents(key)) }
  end

  def searchdiag
    listdiag { |word| @list.set(0, 0, search(word)) }
  end

end

# Mapping the functions to keyboard
module CmdBibControl
  def open
    @list.current != '' && bib.opbib(@list.current(0))
  end

  def print_cur_item
    ask_outfile unless @outfile
    bib.printbibs([@list.current], @outfile)
  end

  def print_all_item
    ask_outfile unless @outfile
    bib.printbibs(bib.db.select(:bibref, :id).flatten, @outfile, 'w')
  end

  def ask_outfile
    listdiag(:file) { |word| set_state(File.expand_path(word)) }
  end

  def addkey(menu)
    keyname = diag_with_msg(nil, :newkey)
    bib.addkey(keyname, menu.current(1)) unless keyname == ''
  end

  def modkey(menu)
    keyname = diag_with_msg(nil, :modkey)
    bib.modkey(menu.current(1), keyname) unless keyname == ''
  end

  def add_ancestorkey(menu)
    keyname = diag_with_msg(nil, :newkey)
    bib.addkey(keyname, Bibus::ANCESTOR) unless keyname == ''
  end

  def delkey(menu)
    bib.dekey(menu.current(0).strip) if asks(:delete)
  end

  def linkey(menu)
    ofs = bib.offsprings(menu.current(1))
    nm = menu.list.transpose.reject { |x| ofs.include?(x[1].to_i) }.transpose
    curses = [menu.curse, menu.scurse]

    showmessage(NormodeBase::INDCSTC[:pkey])
    listmenu(nm, false, curses) { |pnt| bib.adopt(menu.current(1), pnt.to_i) }
    showmessage('')
  end

  def refreshmenu(menu)
    menu.set(menu.curse, menu.scurse, bib.showkeylist)
  end

  MAINFUNCHASH = { # methods that change the shown list
    c: :cstat,
    h: :listhistory,
    l: :listkeys,
    L: :listall,
    R: :refreshpanel,
    s: :searchdiag,
    # methods that change the sqlite data
    a: :add,
    d: :delete,
    n: :noting,
    t: :tag_current,
    u: :update,
    # methods that change nothing
    o: :open,
    p: :print_cur_item,
    P: :print_all_item\
  }

  MENUFUNCHASH = { # methods to deal with keys
    A: :add_ancestorkey,
    a: :addkey,
    d: :delkey,
    m: :modkey,
    l: :linkey\
  }

  def control(char)
    MAINFUNCHASH[char.to_sym] && send(MAINFUNCHASH[char.to_sym])
    showc
  end

  def keycontrol(menu, char)
    #showmessage("#{@menu.current(0)}  #{@menu.current(1)}").getch
    MENUFUNCHASH[char.to_sym] && send(MENUFUNCHASH[char.to_sym], menu)
    refreshmenu(menu)
  end
end

# The main class for cmdbib, including the descriptions for the interface
class CmdBib < CmdBibBase
  include  NormodeBase
  include  CmdBibControl
  attr_reader :list

  public

  def initialize(hght, wth, bib)
    super(bib)
    @scsize, @stat = [hght, wth], :content

    msize = [hght - 6, bib.showkeylist[0].map { |x| x.size }.max + 3]
    @menu = inipanel(msize, [2, (wth - msize[1]) / 2], 0, :minor)

    @diag = Insmode.new('', [@scsize[0] / 3, @scsize[1] * 0.05],
                        [1, @scsize[1] * 0.9], :cmd, ['|', '-'])

    shifts = [0, 0, [wth / 7, 20].max, [wth * 2 / 6, 45].max, wth - 2]
    @list = inipanel([hght -  3, wth], shifts, 3)

    iniwindows(hght - 3, wth, shifts[2])
  end

  def deal
    @list.get { |_, char| control(char) }
  end

  private

  UPKEYS = ['k', KEY_UP]
  DOWNKEYS = ['j', KEY_DOWN, 9, ' ']

  def iniwindows(length, wth, s1)
    @contwin = Framewin.new(length - 2, wth - s1 - 3, 0, s1 + 1, ['|', '-'])
    @state = Framewin.new(1, wth - s1 - 3, length - 1, s1 + 1, ['|', '-'])
    set_state

    @contwin.refresh
    @state.refresh
  end

  def inipanel(size, shifts, mainm, mode = :main)
    menu = AdvMenu.new([[], [], [], []], shifts, [size[0], true], size[1],
                       mainm, ['|', '-'])
    tail = mode == :main ? [10] : []
    menu.setctrl(['q', 10] - tail, DOWNKEYS + tail, UPKEYS)
    menu.setcol([7, false, false])

    menu
  end

  def set_state(outfile = nil)
    @outfile = outfile

    @state.cont.setpos(0, 0)
    @state.cont.attrset(A_BOLD)
    @state.cont.attron(color_pair(COLOR_CYAN))
    @state.cont.addstr("Outfile: #{@outfile}")
  end

  def showc
    showcont(gcont(@list.current)) if @stat == :content
    @state.refresh
    true
  end

  SPLITCHAR = ["\n", ' ', ' ', "\n\n"]
  COLORS = [2, 5, 6, 3]
  def showcont(content)
    @contwin.cont.clear
    @contwin.refresh
    return if content.empty?

    @contwin.cont.setpos(0, 0)
    @contwin.cont.addstr(content.shift + "\n")
    @contwin.cont.attrset(A_BOLD)
    (0..3).each { |i| contadd(content.shift + SPLITCHAR[i], COLORS[i]) }
    @contwin.cont.attroff(A_BOLD)
    contadd(BaseBibUtils.fmtnote(content.shift), 8)

    @contwin.cont.refresh
  end

  def contadd(string, color)
    @contwin.cont.attron(color_pair(color))
    @contwin.cont.addstr(string)
  end
end

def colorinit
  init_pair(1, COLOR_RED, -1)
  init_pair(2, COLOR_GREEN, -1)
  init_pair(3, COLOR_YELLOW, -1)
  init_pair(4, COLOR_BLUE, -1)
  init_pair(5, COLOR_MAGENTA, -1)
  init_pair(6, COLOR_CYAN, -1)
  init_pair(7, COLOR_WHITE, -1)
  init_pair(8, -1, -1)
end
