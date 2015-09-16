#!/bin/env ruby
# encoding: utf-8

# Some extended methods for Hash
class Hash
  def vmap
    return Hash[map { |k, v| [k, yield(v)] }] if sonless?
    Hash[map { |k, v| [k, v.vmap { |x| yield(x) }] }]
  end

  def sonless?
    !values[0].is_a?(Hash)
  end
end

# Some extended methods for Array
class Array
  public

  def gen_hash
    each_with_object({}) { |e, a| a.store(e[0..-2], e[-1]) }
  end
end
