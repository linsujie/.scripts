#!/home/linsj/bin/ruby

class Depend
  attr_reader :hash, :dirs, :lib, :inc, :lib_to_s, :inc_to_s

  def initialize(hash, order = nil)
    @dirs, @lib, @inc = [], [], []
    @hash = hash
    append(hash, order)
  end

  def append(hash, order = nil)
    @hash.merge!(hash)
    readhash(hash)

    sort(order)
    @inc_to_s = @inc.join(' ')
  end

  def sort(order)
    ltmp = @lib.transpose
    @lib_to_s = (ltmp[0] + sort_vec(ltmp[1].flatten, order)).join(' ')
  end

  private

  def readhash(hash, base = nil)
    return unless hash.is_a?(Hash)
    bs = ->(key) { [base, key].compact.join('/') }

    hash.each do |k, v|
      v.is_a?(Array) ? record(bs.call(k), v) : readhash(v, bs.call(k))
    end
  end

  def sort_vec(vector, order)
    return vector unless order
    orderl = order.map { |x| "-l#{x}" }
    orderl + (vector - orderl)
  end

  def unexist?(x)
    return true if @lib.empty?
    @lib.transpose[1].flatten.include?("-l#{x}") ? nil : true
  end

  def record(path, libs)
    @dirs << path
    @lib << ["-L#{path}/lib", libs.map { |x| "-l#{x}" if unexist?(x) }.compact]
    @inc << "-I#{path}/include"
  end
end
