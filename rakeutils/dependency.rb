#!/home/linsj/bin/ruby

class Depend
  attr_reader :dirs, :lib, :inc, :lib_to_s, :inc_to_s

  def initialize(hash, order = nil)
    @dirs, @lib, @inc = [], [], []
    readhash(hash)
    ltmp = @lib.transpose
    @lib_to_s = (ltmp[0] + sort(ltmp[1].flatten, order)).join(' ')
    @inc_to_s = @inc.join(' ')
  end

  private

  def readhash(hash, base = nil)
    return unless hash.is_a?(Hash)
    bs = ->(key) { [base, key].compact.join('/') }

    hash.each do |k, v|
      v.is_a?(Array) ? record(bs.call(k), v) : readhash(v, bs.call(k))
    end
  end

  def sort(vector, order)
    return vector unless order
    orderl = order.map { |x| "-l#{x}" }
    orderl + (vector - orderl)
  end

  def record(path, libs)
    @dirs << path
    @lib << ["-L#{path}/lib", libs.map { |x| "-l#{x}" }]
    @inc << "-I#{path}/include"
  end
end
