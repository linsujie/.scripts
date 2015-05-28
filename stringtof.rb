#!/home/linsj/bin/ruby
# encoding: utf-8

# supply the method e_to_f for String, which could deal with simple expressions
# in String
class String
  def e_to_f
    return to_f unless /(?<![eE])[+*\/-]/ =~ self
    @nums = split(/(?<![eE])[+*\/-]/)
    order = @nums.map { |x| x.size }.reduce([-1]) { |a, e| a << a[-1] + e + 1 }
    @oper = order[1..-2].map { |ind| self[ind] }
    @nums.map! { |x| x.to_f }

    express_act(/[*\/]/)
    express_act(/[+-]/)
    @nums[0]
  end

  private

  def express_act(match)
    return unless ind = @oper.index { |op| op =~ match }

    @nums[ind] = @nums[ind].method(@oper[ind]).(@nums[ind + 1])
    @nums.delete_at(ind + 1)
    @oper.delete_at(ind)
    express_act(match)
  end
end
