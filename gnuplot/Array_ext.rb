#!/usr/local/bin/ruby
# encoding: utf-8

# to extend Array with some methods for gnuplot
class Array
  public

  def reindex(ind = 2.7)
    raise TypeError, 'reindex an unsuitable Array', caller if !transposalbe?
    rind = ->(i) { self[i].zip(self[0]).map! { |f, e| f * e**ind } }

    self.each { |col| col.map! { |x| x.to_f } }
    (1..self.size - 1).each { |i| self[i] = rind.call(i) }
    self
  end

  def drag(*inds)
    inds.map { |i| self[i] }
  end

  private

  def transposalbe?
    self.map { |t| t.size }.uniq.size == 1
  end
end
