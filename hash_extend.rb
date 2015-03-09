#!/bin/ruby

class Hash
  def map
    return Hash[to_a.map { |k, v| [k, yield(v)] }] if sonless?
    Hash[self.to_a.map { |k, v| [k, v.map { |x| yield(x) }] }]
  end

  def sonless?
    !self.values[0].is_a?(Hash)
  end
end

class Array
  public

  def gen_hash
    self.reduce({}) do |a, e|
      a.store(e[0..-2], e[-1])
      a
    end
  end
end
