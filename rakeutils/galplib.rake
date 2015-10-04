require '~/.scripts/rakeutils/dependency.rb'
load '~/.galplib_dir'

deps = { "#{GALPDIRS[:package] || 'MCGAL/package'}": { 'Healpix_2.20a/src/cxx/generic_gcc': %w(healpix_cxx cxxsupport fftpack),
                                                       'ccfits': %w(CCfits),
                                                       'CLHEP': %w(CLHEP),
                                                       'cfitsio': %w(cfitsio) },
         nil => %w(lins works),
         '/usr/local': %w(gsl gslcblas m gfortran),
}
deps.merge!(IFORTLIB)

dftdir = '/home/linsj/MCGAL/galp'
g54 = { "#{GALPDIRS[:g54] || dftdir}": %w(galprop skymap),
        "#{GALPDIRS[:g54c]}": [] }
g55 = { "#{GALPDIRS[:g55] || dftdir}": %w(galprop skymap),
        "#{GALPDIRS[:g55c]}": [],
        "#{GALPDIRS[:gtool] || dftdir}": %w(galstruct nuclei processes random skymap utils),
        "#{GALPDIRS[:xerces] || dftdir}": %w(xerces-c),
        "#{GALPDIRS[:gwrap]}": %w(galpwrap) }

deps.merge!(GALPVERSION == :v55 ? g55 : g54)

order = %w(works galprop lins)
order.insert(1, 'galpwrap') if GALPVERSION == :v55

DEPEND = Depend.new(deps, order)
