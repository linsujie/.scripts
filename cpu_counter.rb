#!/bin/env ruby
# encoding: utf-8

require 'fileutils'

module CpuCounter
  LOGFILE = File.expand_path("~/.cpu_counter.log")
  LOCKFILE = File.expand_path("~/.cpu_counter_lock")

  def user
    file = get_lock
    start_mpstat unless checklog
    file.flock(File::LOCK_UN)

    `tail -n 1 #{LOGFILE}`.split(' ')[-9].to_f
  end

  def checklog
    File.exist?(LOGFILE) && small_enough?(LOGFILE) &&
      (Time.now - File.ctime(LOGFILE)) < 120
  end

  def get_lock
    file = File.new(LOCKFILE, 'w')
    file.flock(File::LOCK_EX)
    file
  end

  def start_mpstat
    ids = running_id
    system("kill #{ids.join(' ')}") unless ids.empty?

    system(cmd + " > #{LOGFILE} &")
    sleep(6)
  end

  def cmd
    'mpstat 5'
  end

  def running_id
    result = `ps x | grep "#{cmd}" | grep -v grep`
    result.each_line.map { |l| l.split(' ')[0] }
  end

  def small_enough?(file)
    File.size(file) < 10 * 1024 * 1024
  end

  def size
    File.size(LOGFILE)
  end
end
