#!/usr/local/bin/ruby
# encoding: utf-8

# to extend Array with some methods for gnuplot
class Array
  public

  REINDEX_WARN = 'reindex an unsuitable Array'
  def reindex(ind = 2.7)
    fail ArguementError, REINDEX_WARN, caller unless transposalbe?
    rind = ->(i) { self[i].zip(self[0]).map! { |f, e| f * e**ind } }

    each { |col| col.map!(&:to_f) }
    (1..size - 1).each { |i| self[i] = rind.call(i) }
    self
  end

  def drag(*inds)
    inds.map { |i| self[i] }
  end

  private

  def transposalbe?
    map(&:size).uniq.size == 1
  end
end
