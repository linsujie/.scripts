require '~/.scripts/rakeutils/dependency.rb'
load '~/.galplib_dir'

DEPS = { "#{GALPDIRS[:galp]}" => %w(galprop skymap),
         "#{GALPDIRS[:source]}" => [],
         "#{GALPDIRS[:packages]}" => PACKAGES,
         nil => %w(lins works)
}

ORDER = %w(works galprop CCFits CLHEP cfitsio lins)

DEPEND = Depend.new(DEPS, ORDER)
