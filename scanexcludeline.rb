#!/bin/env ruby
# encoding: utf-8
require 'json'

class ScanExcludeLine
  DEFAULT_OPT = { command: nil, cl: 0.95, datadir: 'scan_data',
                  xvec: nil, axisname: %w(mchi sv), pflag: false, precision: 0.05,
                  replace: false, ylow: 0.0, yup: 1.0, ygap: 1e40, search_step: 10, bound_value: 1e7
  }
  def initialize(opt)
    @opt = opt
    DEFAULT_OPT.each { |k, v| @opt[k] = v unless @opt.key?(k) }
    @opt[:dchi2] = Chisq::chi2(@opt[:cl], 1)
  end

  def scan
    raise 'ScanExcludeLine::Configure incorrect exit' unless @opt[:command] && @opt[:xvec] && @opt[:axisname] && @opt[:axisname][1]
    FileUtils.mkdir_p(@opt[:datadir])
    @opt[:xvec].each { |x| scan_x(x) }

    raise 'the input xvec is empty' if @opt[:xvec].empty?
  end

  def print(i = nil)
    return unless @opt[:axisname] && @opt[:axisname][1]
    read_xvec

    i = ask_index unless i
    js = JSON.parse(File.new(dataname(@opt[:xvec][i])).read)
    key = [@opt[:axisname][1], 'chi2'] + get_key(js)
    puts "#" + key.join("\t") + "\n" + \
      key.map { |k| js[k] }.transpose.map { |l| format_line(l) }.join("\n")
  end

  def get_key(js)
    (js.keys - [@opt[:axisname], 'chi2'].flatten)
  end

  def print_exclude(fname = nil)
    return unless @opt[:axisname] && @opt[:axisname][1]
    read_xvec

    file = fname ? File.new(fname, 'w') : $stdout

    js = JSON.parse(File.new(dataname(@opt[:xvec][0])).read)
    file.puts "# #{(@opt[:axisname] + get_key(js)).join("\t")}\n" + \
      @opt[:xvec].map { |x| format_line(get_exclude_point(x)) }.join("\n")
  end

  def get_exclude_point(x)
    js = JSON.parse(File.new(dataname(x)).read)
    delta = js['chi2'].map { |x| (x - js['chi2'].min - @opt[:dchi2])**2 }
    index = delta.index(delta.min)
    [x, js[@opt[:axisname][1]][index]] + get_key(js).map { |k| js[k][index] }
  end

  def ask_index
    $stderr.puts "Choose one of the xvalue that you want to print:\n" + \
      @opt[:xvec].each_with_index.map { |x, i| [i + 1, x].join('. ') }.join("\t")

    $stdin.gets.chomp.to_i - 1
  end

  def format_line(line)
    line.map { |x| format("%.6e", x.to_f) }.join("\t")
  end

  def read_xvec
    @opt[:xvec] = Dir.foreach(@opt[:datadir])
    .select { |x| x != '.' && x != '..' && x != 'line' }
    .map { |n| n.sub('.dat', '') }.sort_by { |x| x.to_f }
  end

  def scan_x(x)
    if File.exist?(dataname(x)) && !@opt[:replace]
      puts "ScanExcludeLine::File #{dataname(x)} exist. skip #{x} !"
      return
    end

    @result = { x => {} }
    up = search_for_up(x)
    low = search_for_low(x, up)

    ybest = brent_minimization(low, up) { |v| run(x, v) }

    brent_minimization(low, up) { |v| (run(x, v) - ybest.transpose[1].min - @opt[:dchi2])**2 }

    store_result
  end

  def search_for_up(x)
    yup = @opt[:yup]
    yup *= @opt[:search_step] while(run(x, yup, true) && run(x, yup, true) < @opt[:bound_value])
    while((!run(x, yup, true) || run(x, yup, true) > @opt[:bound_value]))
      yup /= @opt[:search_step]
      raise 'ScanExcludeLine::search_for_up:: no up bound found in the whole range' if yup.zero?
    end

    yup
  end

  def search_for_low(x, yup)
    ylow = @opt[:ylow]
    raise 'ScanExcludeLine::search_for_low::Error::ylow set to be higher than yup' if ylow > yup

    ylow = ylow_next(yup) while(!run(x, ylow, true) || run(x, ylow, true) > @opt[:bound_value])

    raise 'ScanExcludeLine::search_for_low::Error::ylow set to be higher than yup' if ylow > yup
    ylow
  end

  def ylow_next(yup)
    return yup / @opt[:ygap] if ylow.zero?
    ylow * @opt[:search_step]
  end

  def dataname(x)
    "#{@opt[:datadir]}/#{x}.dat"
  end

  def store_result
    x = @result.keys[0]
    key = @result[x].values[0].keys

    out = { @opt[:axisname][0] => x, @opt[:axisname][1] => [] }
    out.merge!(key.map { |k| [k, []] }.to_h)

    @result[x].keys.sort.each do |y|
      next unless @result[x][y]['chi2']
      out[@opt[:axisname][1]] << y
      key.each { |k| out[k] << @result[x][y][k] }
    end

    file = File.new(dataname(x), 'w')
    file.puts JSON.pretty_generate(out)
    file.close
  end

  NGRID = 5
  def grid(low, up)
    (0..NGRID - 1).to_a.map { |i| low + i * (up - low) / (NGRID - 1) }
  end
  def search_for_range(low, up)
    arrs = grid(low, up).map { |y| yield(y) }

    i = minindex(arrs)
    return [low, arrs[i][0], up] if i != 0

    peak = arrs.each_cons(2).find { |f, s| s[1] < f[1] }
    return search_for_range(peak[0][0], up) { |y| yield(y) } if peak
    return [low, arrs[1][0], up] if (arrs[-1][1] - arrs[0][1])**2 < @opt[:precision]**2

    search_for_range(low, arrs[-2][0]) { |y| yield(y) }
  end

  def brent_minimization(xmin, xmax)
    low, med, up = search_for_range(xmin, xmax) { |v| [v, yield(v)] }

    points = [low, med, up].map { |v| [v, yield(v)] }

    points = brent_iter(points) { |x| yield(x) } while(!points_close(points))
    points
  end

  def points_close(points)
    values = points.transpose[1]
    (values.max - values.min) < @opt[:precision] || values.uniq.size < 3
  end

  def brent_iter(points)
    a, fa = points[0]
    b, fb = points[1]
    c, fc = points[2]

    x = b - 1.0 / 2.0 * ( (b-a)**2 * (fb-fc) - (b-c)**2 * (fb-fa) ) / ( (b-a) * (fb-fc) - (b-c) * (fb-fa) )

    points << [x, yield(x)]

    points.sort_by! { |x, _| x }

    (minindex(points) < 2) ?  points.delete_at(3) : points.delete_at(0)
    points
  end

  def minindex(arr)
    arr.index(arr.min_by { |_, fx| fx })
  end

  def run(x, y, force = false)
    cmd_result = nil
    if !(@result[x] && @result[x][y])
      cmd_result = `#{[@opt[:command], x, y].join(' ')}`.split("\n")[-1]
      @result[x].store(y, JSON.parse(cmd_result))
      puts [x, y, @result[x][y]['chi2']].join(' ') if @opt[:pflag]
    end

    if (!force && !@result[x][y]['chi2'])
      raise "ScanExcludeLine::command #{[@opt[:command], x, y].join(' ')}"\
            "                 get nil result #{cmd_result}, please check"
    end
    @result[x][y]['chi2']
  end
end

