#!/usr/bin/env ruby
# encoding: utf-8

# A tree
class Tree
  attr_accessor :val, :children

  public

  def initialize(value, value_name = %w(value))
    @@value_name ||= value_name.map(&:to_sym)
    @val, @children = Hash[[@@value_name, value].transpose], []

    @@value_name.each { |val| Tree.define_value(val) }
  end

  def self.set_list(value_name)
    @@value_name = value_name.map { |x| x.to_sym }
  end

  def <<(value)
    subtree = Tree.new(value)
    @children << subtree
    return subtree
  end

  def find(word = :val, val)
    return self if send(word) == val
    res = @children.each { |child| (c = child.find(word, val)) && (break c) }
    res if !res.is_a?(Array)
  end

  def eachs(*arr)
    yield(arr.map { |x| send(x) })
    @children.each { |child| child.eachs(*arr) { |e| yield e } }
  end

  def each(word = :val)
    yield send(word)
    @children.each { |child| child.each(word) { |e| yield e } }
  end

  def map!(word = :val, *app)
    append = ->(word, app) { [*app].unshift(word).map(&:send) }
    send("#{word}=", yield(app.empty? ? send(word) : append.call(word, app)))
    @children.each { |child| child.map!(word, *app) { |e| yield e } }
  end

  def copy(another, idval, val)
    return unless another.is_a?(Tree)

    copytree(another, self, idval, val)
  end

  def sort!(word)
    @children.sort_by! { |x| x.send(word) }
    @children.each { |child| child.sort!(word) }
    self
  end

  def to_a(gen = 0)
    recdeal = ->(a, e) { a + e.to_a(gen + 1) { |v, g| yield(v, g) } }
    @children.reduce([yield(@val, gen)]) { |a, e| recdeal.call(a, e) }
  end

  private

  def copytree(ori, tar, idval, val)
    return unless tar.val[idval] == ori.val[idval]

    tar.val[val] = ori.val[val]
    getmap = ->(indenum) { indenum.map { |s, i| [s.val[idval], i] }.to_h }
    getind = ->(tree) { getmap.call(tree.children.each_with_index) }
    m_tar, m_ori = getind.call(tar), getind.call(ori)

    (m_tar.each_key.to_a & m_ori.each_key.to_a).each do |ind|
      copytree(ori.children[m_ori[ind]], tar.children[m_tar[ind]], idval, val)
    end
  end

  def self.define_value(val)
    define_method(val) { @val[val.to_sym] }
    define_method("#{val}=") { |v| @val[val.to_sym] = v }
  end
end
