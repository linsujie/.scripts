require '~/.scripts/rakeutils/dependency.rb'
load '~/.galplib_dir'

deps = { "#{GALPDIRS[:galp]}" => %w(galprop skymap),
         "#{GALPDIRS[:source]}" => [],
         "#{GALPDIRS[:packages]}" => PACKAGES,
         nil => %w(lins works)
}
deps.merge!(EXTRA)

order = %w(works galprop CCFits CLHEP cfitsio lins)
order.insert(1, 'galpwrap') if GALPVERSION == :v55

DEPEND = Depend.new(deps, order)
