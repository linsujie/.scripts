#!/usr/env ruby
# encoding: utf-8

# extend Array with to_range method
class Array
  def to_range
    split_by {|i, j| j - i != 1 }.map{ |a| a.first..a.last }
  end

  private

  def split_by
    each_cons(2).inject([[first]]) do |a, (i, j)|
      a.push([]) if yield(i, j)
      a.last.push j
      a
    end
  end
end

# A class to store an manipulate the information of a table
class Table
  attr_reader :col_size, :line_size

  def initialize
    @content = []
    @col_size = 0
    @line_size = 0
  end

  def transpose!
    @content = @content.transpose
    @content.map! { |l| l.map! { |e| transpose_element(e) } }
    @col_size, @line_size = @line_size, @col_size
  end

  %w(push unshift).each do |action|
    define_method("#{action}_line") do |vec|
      @content.send(action, (0..@col_size - 1).map { |i| element(vec[i]) })
      @line_size += 1
    end

    define_method("#{action}_col") do |vec|
      (0..@line_size - 1).each do |i|
        @content[i].send(action, element(vec[i]))
      end
      @col_size += 1
    end
  end

  def insert_line(iline, vec = [])
    @content.insert(iline, (0..@col_size - 1).map { |i| element(vec[i].to_s) })
    (0..@col_size - 1).each do |icol|
      combine_up(iline, icol) unless up_ele?(iline + 1, icol)
    end
    @line_size += 1
  end

  def insert_col(icol, vec = [])
    (0..@line_size - 1).each do |iline|
      @content[iline].insert(icol, element(vec[iline].to_s))
      combine_left(iline, icol) unless left_ele?(iline, icol + 1)
    end
    @col_size += 1
  end


  %w(pop shift).each do |action|
    define_method("#{action}_line") do
      @content.send(action)
      @line_size -= 1
    end

    define_method("#{action}_col") do
      (0..@line_size - 1).each { |i| @content[i].send(action) }
      @col_size -= 1
    end
  end

  def combine_up(iline, icol)
    return if iline == 0
    refresh_line(iline)
    refresh_col(icol)

    target = self[iline - 1, icol]
    iline_main, icol_main = iline - 1 - target[:vshift], icol - target[:shift]

    self[iline_main, icol_main][:vsize] += 1

    refresh_large_element(iline_main, icol_main)
  end

  def combine_left(iline, icol)
    return if icol == 0
    refresh_line(iline)
    refresh_col(icol)

    target = self[iline, icol - 1]
    iline_main, icol_main = iline - target[:vshift], icol - 1 - target[:shift]

    self[iline_main, icol_main][:size] += 1

    refresh_large_element(iline_main, icol_main)
  end

  def []=(iline, icol, string)
    refresh_line(iline)
    refresh_col(icol)

    @content[iline][icol][:string] = string
  end

  def [](iline, icol)
    @content[iline] && @content[iline][icol]
  end

  def max_width(iline)
    (0..@col_size - 1).map { |ic| self[iline, ic][:size] }.max
  end

  def max_height(icol)
    (0..@line_size - 1).map { |il| self[il, icol][:vsize] }.max
  end

  def string(iline, icol)
    return self[iline, icol][:string] if main_ele?(iline, icol)
    medium = self[iline, icol]

    self[iline - medium[:vshift], icol - medium[:shift]][:string]
  end

  def main_ele?(iline, icol)
    self[iline, icol][:string] != :ref_main
  end

  def left_ele?(iline, icol)
    self[iline, icol][:shift] == 0
  end

  def right_ele?(iline, icol)
    self[iline, icol][:size] - self[iline, icol][:shift] == 1
  end

  def up_ele?(iline, icol)
    self[iline, icol][:vshift] == 0
  end

  def down_ele?(iline, icol)
    self[iline, icol][:vsize] - self[iline, icol][:vshift] == 1
  end

  def print(ele_width = 12, splitor = ' ')
    puts (0..@line_size - 1).map { |il| line_str(il, ele_width, splitor) }
      .join("\n")
  end

  def print_latex(ele_width = 20)
    puts latex_str(ele_width)
  end

  def latex_str(ele_width = 20)
    str = "\\begin{tabular}{#{'c' * @col_size}}\n\\hline\n"
    str << (0..@line_size - 1).map { |il| line_str_latex(il, ele_width) }
      .join("\n")

    str << "\\hline\n\\end{tabular}"
  end

  def line_splitor_vector(iline)
    head_spl = (0..@col_size - 1).map { |ic| self[iline, ic][:size] > 1 }
   return head_spl if (self[iline, 0][:vsize] == 1)

   need_line = false
   (0..@col_size - 1).map { |ic| need_line ||= need_line_splitor?(iline, ic)  }
  end

  private

  def transpose_element(element)
    element[:vsize], element[:size] = element[:size], element[:vsize]
    element[:vshift], element[:shift] = element[:shift], element[:vshift]
    element
  end

  def line_str(iline, ele_width, splitor = ' ')
    (0..@col_size - 1).map { |ic| element_str(iline, ic, ele_width, splitor) }
    .compact.join(splitor) << line_splitor(iline, ele_width, splitor.size)
  end

  def line_str_latex(iline, ele_width = 20)
    (0..@col_size - 1).map { |ic| element_str_latex(iline, ic, ele_width) }
    .compact.join(' & ') << '\\\\' << line_splitor_latex(iline)
  end

  def line_splitor_latex(iline)
    result = line_splitor_vector(iline).each_with_index.select { |b, _| b }
    .map { |_, i| i + 1 }

    return '' if result.empty?
    result.to_range.map { |r| "\\cline{#{r.to_s.sub('..', '-')}}" }.join
  end

  def line_splitor(iline, ele_width, splitor_size)
   bool_spl = line_splitor_vector(iline)
   char_spl = bool_spl.map { |b| (b ? '-' : ' ') * ele_width }

   line = ->(s) { "\n" << s[1..-1].reduce(s[0]) { |a, e| a << (e[0] * splitor_size) << e } }
   bool_spl.reduce(false, &:|) ? line.call(char_spl) : ''
  end

  def need_line_splitor?(iline, ic)
    down_ele?(iline, ic) && self[iline, ic][:vsize] != 1 ||
      iline + 1 < @line_size && up_ele?(iline + 1, ic) && self[iline + 1, ic][:vsize] != 1
  end

  def element_str(iline, icol, ele_width, splitor)
    return unless center?(iline, icol)

    str = vcenter?(iline, icol) ? string(iline, icol).to_s : ''

    ele_number = self[iline, icol][:size]
    width = ele_width * ele_number + (ele_number - 1) * splitor.size
    str[0..width - 1].center(width)
  end

  def element_str_latex(iline, icol, ele_width)
    return if up_ele?(iline, icol) && !main_ele?(iline, icol)

    str = latex_form_str(iline, icol)

    n_ele = self[iline, icol][:size]
    ele_width = ele_width * n_ele + (n_ele - 1) * 3 if main_ele?(iline, icol)
    str.center(ele_width)
  end

  def latex_form_str(iline, icol)
    return '' unless main_ele?(iline, icol)

    element = self[iline, icol]
    str = element[:string].to_s
    str = "\\multirow{#{element[:vsize]}}{*}{#{str}}" if element[:vsize] > 1
    str = "\\multicolumn{#{element[:size]}}{c}{#{str}}" if element[:size] > 1
    str
  end

  def center?(iline, icol)
    ele = self[iline, icol]
    ele[:shift] == ele[:size] / 2
  end

  def vcenter?(iline, icol)
    ele = self[iline, icol]
    ele[:vshift] == ele[:vsize] / 2
  end

  def refresh_large_element(iline, icol)
    e = self[iline, icol]

    (0..e[:vsize] - 1).to_a.product((0..e[:size] - 1).to_a).each do |il, ic|
      next if il == 0 && ic == 0
      obj = self[iline + il, icol + ic]
      obj[:string] = :ref_main
      [:vsize, :size].each { |k| obj[k] = e[k] }
      obj[:vshift] = il
      obj[:shift] = ic
    end
  end

  def element(str = nil)
    { string: str, vsize: 1, size: 1, vshift: 0, shift: 0 }
  end

  def refresh_line(iline)
    return if iline < @line_size
    (@line_size..iline).each do |i|
      @content[i] = []
      @col_size.times { @content[i].push(element) }
    end
    @line_size = iline + 1
  end

  def refresh_col(icol)
    return if icol < @col_size
    (0..@line_size - 1).each do |i|
      (icol - @col_size + 1).times { @content[i].push(element) }
    end
    @col_size = icol + 1
  end
end
