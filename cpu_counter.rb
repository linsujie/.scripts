#!/bin/env ruby
# encoding: utf-8

require 'fileutils'

module CpuCounter
  LOGFILE = File.expand_path("~/.cpu_counter.log")

  def user
    start_mpstat unless checkfile(LOGFILE)

    `tail -n 1 #{LOGFILE}`.split(' ')[-9].to_f
  end

  def checkfile(file)
    File.exist?(LOGFILE) && small_enough?(LOGFILE) &&
      (Time.now - File.ctime(file)) < 120
  end

  def start_mpstat
    ids = running_id(cmd)
    system('killall mpstat') unless ids.empty?

    Process.spawn(cmd)
    sleep(6)
  end

  def cmd
    "mpstat 5 > #{LOGFILE}"
  end

  def running_id(cmd)
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
