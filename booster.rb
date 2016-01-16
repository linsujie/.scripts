#!/bin/env ruby
# encoding: utf-8

require 'matrix'

class Booster
  def initialize(velocity)
    raise 'Booster::please input an available velocity' unless check(velocity)

    @beta = Math.sqrt(velocity.reduce(0) { |a, e| a + e * e })
    @n = velocity.map { |x| x / @beta }
    @gamma = 1 / Math.sqrt(1 - @beta * @beta)

    matrix_t = [@gamma] + (0..2).map { |i| - @gamma * @beta * @n[i] }

    @BMatrix = Matrix[matrix_t, *(0..2).map { |i| matrix_s(i) }]
  end

  def boost(vector)
    (@BMatrix * Matrix[vector].transpose).transpose.to_a[0]
  end

  private

  def matrix_s(i)
    weight =->(m, n) { (@gamma - 1) * @n[m] * @n[n] }

    [-@gamma * @beta * @n[i]] + \
      (0..2).map { |j| (@gamma - 1) * @n[j] * @n[i] + (i == j ? 1 : 0) }
  end

  def check(velocity)
    velocity.size == 3 and
      velocity.reduce(true) { |a, e| a && (e.is_a?(Float) || e.is_a?(Fixnum)) } and
      velocity.reduce(0) { |a, e| a + e * e } <= 1
  end
end
