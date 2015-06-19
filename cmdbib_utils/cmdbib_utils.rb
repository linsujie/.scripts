#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'note.rb'

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
    @list.set(@list.curse, @list.scurse, obtainlist(@list.to_a(3)))
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

    filename = diag_with_msg(:file, :fileask)
    bibname = diag_with_msg(:file, :bibask)

    update_item(bibname) if bibname != ''

    ident = bib.db.select(:bibref, :identifier, :id, @list.current(-1))[0][0]
    bib.addfile(filename, ident) if filename != ''
  end

  def update_item(bibname)
    bib.modbib(@list.current(-1), bibname)
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
    showmessage(Message::INDCSTC[msg_type])
    result = listdiag(comp_type, Message::INDCSTC[msg_type])
    showmessage('')
    result
  end

  def back_bibfile(bibname)
    bibname = File.expand_path(bibname)
    FileUtils.mv(bibname, TMPFILE) unless bibname == TMPFILE
  end

  def tag_current
    ltb = bib.keys(@list.current(-1))
    ltb.each { |k| @menu.fdlist.tag(k)  }
    @menu.set

    keyid = @menu.get(1) { |_, state, _| showc; state }
    bib.link_item(keyid, @list.current(-1)) if @menu.char != 'q' && asks(:tag)

    ltb.each { |k| @menu.fdlist.tag(k)  }
    @menu.set
  end

  def delete
    bib.debib(@list.current(-1), "y\n") if asks(:delete)
  end

  def cstat
    @stat = @stat == :content ? :list : :content
    visible = @stat == :content ? [7, nil, nil, nil] : [7, 5, true, false]
    @list.setcol(visible)
  end

  def noting
    return if @list.current(-1) == ''
    clear
    ((author, title, notes)) = bib.db
      .select(:bibref, %w(author title note), :id, @list.current(-1))

    head = [title, author, @list.current(0)]
    pad = NoteItf.new(notes, head, @scsize, @scsize[1], 1)

    pad.deal
    bib.storenote(@list.current(-1), pad.note.notes)
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

  KEY_STATE_MAP = { normal: { l: :link },
                    link: { q: :normal, '10': :normal } }

  def chstate(fdlist, lastid, state, newstate)
    if state == :normal && newstate == :link
      @lastnode = fdlist.tree.find(:id, lastid)
      @lastnodestate, @lastnode.ostate = @lastnode.ostate, nil
      showmessage(Message::INDCSTC[:pkey])
    elsif state == :link && newstate == :normal
      @lastnode.ostate = @lastnodestate
      showmessage('')
    end
    @menu.set
  end

  def listkeys
    lastid = 0
    key = @menu.get(1) do |fdlist, state, char|
      keycontrol(state, char, [@menu.current(1).to_i, lastid])
      showc

      newstate = KEY_STATE_MAP[state][char] || state

      if newstate != state
        lastid = @menu.current(1).to_i
        chstate(fdlist, lastid, state, newstate)
      end

      state = newstate
    end

    @list.set(0, 0, keyidents(key)) if @menu.char != 'q'
  end

  def searchdiag
    listdiag { |word| @list.set(0, 0, search(word)) }
  end
end

# Mapping the functions to keyboard
module CmdBibControl
  def open
    @list.current(-1) != '' && bib.opbib(@list.current(0))
  end

  def print_cur_item
    ask_outfile unless @outfile
    bib.printbibs([@list.current(-1)], @outfile)
  end

  def print_all_item
    ask_outfile unless @outfile
    bib.printbibs(bib.db.select(:bibref, :id).flatten, @outfile, 'w')
  end

  def ask_outfile
    listdiag(:file) { |word| set_state(File.expand_path(word)) }
  end

  def addkey(ids)
    keyname = diag_with_msg(nil, :newkey)
    bib.addkey(keyname, ids[0]) unless keyname == ''
  end

  def modkey(ids)
    keyname = diag_with_msg(nil, :modkey)
    bib.modkey(ids[0], keyname) unless keyname == ''
  end

  def add_ancestorkey(ids)
    keyname = diag_with_msg(nil, :newkey)
    bib.addkey(keyname, bib.ancestor) unless keyname == ''
  end

  def delkey(ids)
    bib.dekey(ids[0]) if asks(:delete)
  end

  def linkey(ids)
    bib.adopt(ids[1], ids[0])
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

  MENUFUNC = { # methods to deal with keys
    normal: { A: :add_ancestorkey,
              a: :addkey,
              d: :delkey,
              m: :modkey, },
    null: {},
    link: { '10': :linkey },
  }

  def control(char)
    MAINFUNCHASH[char.to_sym] && send(MAINFUNCHASH[char.to_sym])
    showc
  end

  def keycontrol(state, char, currents)
    if MENUFUNC[state] && MENUFUNC[state][char]
      send(MENUFUNC[state][char], currents)
      @menu.set(bib.biblist)
    end

    showc
  end
end

# The main class for cmdbib, including the descriptions for the interface
class CmdBib < CmdBibBase
  include  Message
  include  CmdBibControl
  attr_reader :list

  public

  def initialize(hght, wth, bib)
    super(bib)
    @scsize, @stat = [hght, wth], :content

    @menu = FoldMenu.new(bib.biblist,
                         { xshift: [(wth - bib.biblist.size) / 2], yshift: 2,
                           fixlen: nil, length: hght - 6 })
    @menu.setctrl(['q', 10], DOWNKEYS, UPKEYS)
    @menu.setcol([6])

    @diag = Insmode.new('', [@scsize[0] / 3, @scsize[1] / 20],
                        [1, @scsize[1] * 0.9], :cmd, ['|', '-'])

    shifts = [0, [wth / 6, 25].max, [wth * 2 / 7, 45].max, wth - 2]
    @list = AdvMenu.new([[]] * 4, { xshift: shifts[0..2],
                                    width: shifts[3] - shifts[2],
                                    length: hght - 3 })
    @list.setctrl(['q'], DOWNKEYS + [10], UPKEYS)
    @list.setcol([7, false, false])

    iniwindows(hght - 3, wth, shifts[1])
  end

  def deal
    @list.get { |_, char| control(char) }
  end

  private

  UPKEYS = ['k', KEY_UP]
  DOWNKEYS = ['j', KEY_DOWN, 9, ' ']

  def iniwindows(length, wth, s1)
    @contwin = Framewin.new(length - 2, wth - s1 - 3, 0, s1, %w(| -))
    @state = Framewin.new(1, wth - s1 - 3, length - 1, s1, %w(| -))
    set_state

    @contwin.refresh
    @state.refresh
  end

  def set_state(outfile = nil)
    @outfile = outfile

    @state.cont.setpos(0, 0)
    @state.cont.attrset(A_BOLD)
    @state.cont.attron(color_pair(COLOR_CYAN))
    @state.cont.addstr("Outfile: #{@outfile}")
  end

  def showc
    showcont(gcont(@list.current(-1))) if @stat == :content
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
