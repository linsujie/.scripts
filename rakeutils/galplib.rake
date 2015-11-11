require '~/.scripts/rakeutils/dependency.rb'
load '~/.galplib_dir'

deps = { "#{GALPDIRS[:galp]}" => %w(galprop skymap),
         "#{GALPDIRS[:source]}" => [],
         "#{GALPDIRS[:packages]}" => PACKAGES,
}
deps.merge!(EXTRA)

order = %w(galpwrap galprop CCfits CLHEP cfitsio)

DEPEND = Depend.new(deps, order)
