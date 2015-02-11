#!/home/linsj/bin/ruby

filename = ARGV[0] || 'carbon.dat'

file = File.new(filename)
hash = {}
key = nil
val = 0
while (line = file.gets)
  if line.match(/#(.+)/)
    hash.store(key, val) if key
    key = $&.to_sym
    val = 0
  else
    val += 1
  end
end
hash.store(key, val)

p hash
