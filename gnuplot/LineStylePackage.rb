#!/home/linsj/bin/ruby
# encoding: utf-8

# A simple counter to counter to provide the index number for LineStylePackage
class RectangleCounter
  def initialize(sizes)
    @sizes, @iter = sizes, -1
  end

  def get(iter = nil)
    iter ||= (@iter += 1)

    @sizes.reduce([]) do |a, e|
      a << iter % e
      iter /= e
      a
    end
  end
end

# The class to provide a { lt: xx, lc: xx, lw: xx } hash that changes iteratively
class LineStylePackage
  attr_reader :packs
  def initialize(lws = nil, lcs = nil, lts = nil)
    @iter = -1
    @vechash = Hash[tcwlab('wct').zip([lws || LW, lcs || LC, lts || LT])]

    tcw = %w(t c w).permutation.map { |x| x.join }
    @counter = Hash[tcw.map { |x| [x, RectangleCounter.new(tcwsize(x))] }]
    tcw.each { |x| LineStylePackage.definetcw(x) }
  end

  def self.definetcw(seq)
    define_method("l#{seq}") do |iter = nil|
      result = tcwlab(seq).map { |l| [l, @vechash[l]] }
        .zip(@counter[seq].get(iter)).map { |cont, i| [cont[0], cont[1][i]] }
      Hash[result]
    end
  end

  private

  LW = [3, 6]
  LC = %w(FF0000 0000FF 008800 FF8800 FF00FF 0088FF 888888 000000)
    .map { |x| "rgb '##{x}'" }
  LT = [1, 2, 4, 5, 7, 8]

  def tcwlab(sequence)
    sequence.each_char.map { |x| "l#{x}".to_sym }
  end

  def tcwsize(sequence)
    tcwlab(sequence).map { |x| @vechash[x].size }
  end
end
