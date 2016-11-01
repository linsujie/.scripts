#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'linestylepackage'
require_relative 'range'
require_relative 'mapdata'
require 'test/unit'

class TestGnuplotUtils < Test::Unit::TestCase
  include  PlotUtils
  def test_linestylepackage
    ls = LineStylePackage.new(lw: [1,2,3], lc: %w(FF0000 00FF00 0000FF), lt: [2, 4, 6])

    assert_equal(ls.ltcw, lt: 2, lc: "rgb '#FF0000'", lw: 1)
    assert_equal(ls.ltcw, lt: 4, lc: "rgb '#FF0000'", lw: 1)
    assert_equal(ls.ltcw, lt: 6, lc: "rgb '#FF0000'", lw: 1)
    assert_equal(ls.ltcw, lt: 2, lc: "rgb '#00FF00'", lw: 1)

    assert_equal(ls.lcwt, lt: 2, lc: "rgb '#FF0000'", lw: 1)
    assert_equal(ls.lcwt, lt: 2, lc: "rgb '#00FF00'", lw: 1)
    assert_equal(ls.lcwt, lt: 2, lc: "rgb '#0000FF'", lw: 1)
    assert_equal(ls.lcwt, lt: 2, lc: "rgb '#FF0000'", lw: 2)
  end

  def test_range
    fake_specs = [[[1, 2, 3, 4, 5], [-2, -1, 0, 1, 2]],
                  [[2, 3, 4, 5, 6], [2, 1, 0, -1, -2]],
                  [[1, 2, 3, 4, 5], [1, 1, 1, 1, 1]],
                  [[1, 2, 3, 4, 5], [-1, -1, -1, -1, -1]],
                  [[1, 2, 3, 4, 5], [0, 0, 0, 0, 0]]]

    range = Range.new
    range.inputx fake_specs[0][0]
    assert_equal(fake_specs[0][0], range.x)

    fake_specs.each { |spec| range.input(spec) }
    assert_equal([3, 2, 1, 1, 2], range.max)
    assert_equal([1e-300] * 5, range.min)

    range = Range.new(false)
    range.inputx fake_specs[0][0]
    assert_equal(fake_specs[0][0], range.x)

    fake_specs.each { |spec| range.input(spec) }
    assert_equal([3, 2, 1, 1, 2], range.max)
    assert_equal([-2, -1, -1, -1, -1], range.min)
  end

  def compare_mapdata(dat1, dat2)
    assert_equal(dat1.xaxis, dat2.xaxis)
    assert_equal(dat1.yaxis, dat2.yaxis)
    assert_equal(dat1.contval, dat2.contval)
    assert_equal(dat1.array, dat2.array)
    assert_equal(dat1.cols, dat2.cols)
    assert_equal(dat1.xsize, dat2.xsize)
    assert_equal(dat1.ysize, dat2.ysize)
  end

  def test_real_mapdata
    table = 'testdata/plot_data/test_2D_2_1'
    contour_val = 'testdata/plot_data/test_2D_2_1_cont'
    x = 'testdata/plot_data/test_p1.dat'
    y = 'testdata/plot_data/test_p2.dat'

    contour = File.new(contour_val).each.to_a[0].split(' ')
    dat = MapData.new([table, x, y], :arrayfile)
    dat.setcontour(contour)

    dat.setpowscale(:y)

    arrname = "testdata/test_arr"
    dat.printarray(arrname)
    datarr = MapData.new([arrname, "#{arrname}x", "#{arrname}y"], :arrayfile)

    colname = "testdata/test_col.dat"
    dat.printcols(colname)
    datcol = MapData.new(colname, :colsfile)

    compare_mapdata(datarr, datcol)
  end

  def test_simple_mapdata
    fakex = [1, 2, 3]
    fakey = [0.2, 0.3]
    fake_arr = [[0.1, 0.2, 0.3],
                [0.4, 0.5, 0.6]]

    fake_cols = [[1,   1,   nil, 2,   2,   nil, 3,   3],
                 [0.2, 0.3, nil, 0.2, 0.3, nil, 0.2, 0.3],
                 [0.1, 0.4, nil, 0.2, 0.5, nil, 0.3, 0.6]]

    datarr = MapData.new([fake_arr, fakex, fakey], :array)
    datcol = MapData.new(fake_cols, :cols)

    compare_mapdata(datarr, datcol)
  end

  def test_plotutils
    testdat = 'testdata/read_test.dat'
    arr = [[1.1, 2.3], [1.2, 3.3], [1.3, 4.3], [2.0, 3.4], [3.0, 3.3],
           [3.0, 1.0], [5.0, 2.3], [6.0, 0.3]]
    assert_equal(arr, readdata(testdat, :keep))

    hash = { ' first' => [['1.1', '1.2', '1.3'], ['2.3', '3.3', '4.3']], 
             ' second' => [['2', '3'], ['3.4', '3.3']],
             ' third'=>[['3', '5', '6'], ['1', '2.3', '0.3']] }
    assert_equal(hash, readexpdata(testdat))
  end
end
