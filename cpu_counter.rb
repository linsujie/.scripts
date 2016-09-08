#!/bin/env ruby
# encoding: utf-8

require 'fileutils'

class CpuCounter
  LOGFILE = File.expand_path("~/.cpu_counter.log")
  def initialize
    ObjectSpace.define_finalizer(self, proc { system("pkill -TERM -P #{@pid}") if @pid; FileUtils.rm(LOGFILE) })
  end

  def user
    start_mpstat unless File.exist?(LOGFILE)

    `tail -n 1 #{LOGFILE}`.split(' ')[-9].to_f
  end

  def start_mpstat
    @pid = Process.spawn("mpstat 5 > #{LOGFILE}")
    sleep(6)
  end
end
