#!/home/linsj/bin/ruby
# encoding: utf-8

# A simple counter to counter to provide the index number for LineStylePackage
class RectangleCounter
  def initialize(sizes)
    @sizes = sizes
    @iter = -1
  end

  def reset(iter = -1)
    @iter = iter
  end

  def get(iter = nil)
    iter ||= (@iter += 1)

    @sizes.each_with_object([]) do |e, a|
      a << iter % e
      iter /= e
    end
  end
end

# The class to provide a { lt: xx, lc: xx, lw: xx } hash that changes
# iteratively
class LineStylePackage
  attr_reader :vechash

  def initialize(vechash = DEFAULT_HASH)
    @iter = -1
    @vechash = vechash
    DEFAULT_HASH.each { |k, v| @vechash[k] = v unless @vechash.key?(k) }
    @vechash[:lc] = @vechash[:lc].map { |x| "rgb '##{x}'" }

    tcw = %w(t c w).permutation.map(&:join)
    @counter = Hash[tcw.map { |x| [x, RectangleCounter.new(tcwsize(x))] }]
    tcw.each { |x| LineStylePackage.definetcw(x) }
  end

  def self.definetcw(seq)
    define_method("l#{seq}") do |iter = nil|
      result = tcwlab(seq).zip(@counter[seq].get(iter))
               .map { |type, ind| [type, @vechash[type][ind]] }

      Hash[result]
    end

    define_method("reset#{seq}") do |iter = -1|
      @counter[seq].reset(iter)
    end
  end

  private

  DEFAULT_HASH = { lw: [3, 6],
                   lc: %w(FF0000 0000FF 008800 FF8800 FF00FF 0088FF 888888
                          000000),
                   lt: [1, 2, 4, 5, 7, 8] }

  def tcwlab(sequence)
    sequence.each_char.map { |x| "l#{x}".to_sym }
  end

  def tcwsize(sequence)
    tcwlab(sequence).map { |x| @vechash[x].size }
  end
end
