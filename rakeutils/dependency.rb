#!/home/linsj/bin/ruby

class Depend
  attr_reader :dirs, :lib, :inc, :lib_to_s, :inc_to_s

  def initialize(hash)
    @dirs, @lib, @inc = [], [], []
    readhash(hash)
    @lib_to_s = @lib.join(' ')
    @inc_to_s = @inc.join(' ')
  end

  private

  def readhash(hash, base = nil)
    return unless hash.is_a?(Hash)
    bs = ->(key) { base ? "#{base}/#{key}" : key }

    hash.each do |k, v|
      v.is_a?(Array) ? record(bs.call(k), v) : readhash(v, bs.call(k))
    end
  end

  def record(path, libs)
    @dirs << path
    @lib << ["-L#{path}/lib", libs.map { |x| "-l#{x}" }]
    @inc << "-I#{path}/include"
  end
end
