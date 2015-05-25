require '~/.scripts/rakeutils/dependency.rb'
DEPS = { '/home/linsj': { 'MCGAL/galp': %w(galprop skymap),
                          'MCGAL/package': { 'Healpix_2.20a/src/cxx/generic_gcc': %w(healpix_cxx cxxsupport fftpack),
                                             'ccfits': %w(CCfits),
                                             'CLHEP': %w(CLHEP),
                                             'cfitsio': %w(cfitsio) },
                          nil => %w(lins works) },
         '/usr/local': %w(gsl gslcblas m gfortran),
         '/opt/intel/Compiler/11.1/046/lib/intel64': %w(ifport ifcoremt imf svml ipgo iomp5 irc pthread irc_s dl)
}

ORDER = %w(works galprop lins)

DEPEND = Depend.new(DEPS, ORDER)
