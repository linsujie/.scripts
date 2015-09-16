#!/bin/env ruby
# encoding: utf-8
# My default setting for highline
require 'highline/import'

def choose_wrap(sentence, choices, colnum = 5)
  choose do |menu|
    menu.header = sentence
    menu.layout = :list

    menu.select_by = :index
    menu.flow = :columns_down
    menu.list_option = colnum

    menu.index = :number

    menu.choices(*choices)
  end
end
