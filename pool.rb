#!/bin/env ruby
# encoding: utf-8

require_relative 'cpu_counter'

include CpuCounter

# A Thread Pool to limit the max number of threads
class Pool
  attr_reader :pool, :jobs

  def initialize(size, sleep_count = nil, cpu_limit = 90)
    @size = size
    @jobs = Queue.new
    @pool = Array.new(@size) do |i|
      Thread.new do
        sleep(sleep_count * i) if sleep_count
        Thread.current[:id] = i
        catch(:exit) do
          loop do
            job, args = @jobs.pop
            sleep(20) while CpuCounter::user > cpu_limit
            job.call(*args)
          end
        end
      end
    end
  end

  def schedule(*args, &block)
    @jobs << [block, args]
  end

  def shutdown
    @size.times do
      schedule { throw :exit }
    end
    @pool.map(&:join)
  end
end
