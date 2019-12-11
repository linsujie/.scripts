#include <Math/Integrator.h>
#include <Math/IntegrationTypes.h>
#include <Math/Interpolator.h>
#include <TString.h>

#include <cstring>
#include <vector>
#include <fstream>
#include <sstream>

using namespace std;

class InterpFunc
{
private:
  bool lneval;
  vector<double> x, y, lnx, lny;
  ROOT::Math::Interpolator intp, lnintp;

  void readfile(const string& file) {
    x.clear(); y.clear(); lnx.clear(); lny.clear();

    ifstream data(file);
    string line;
    double xtmp, ytmp;
    while(getline(data, line)) {
      istringstream is(line);
      is >> xtmp >> ytmp;
      x.push_back(xtmp);
      y.push_back(ytmp);
      lnx.push_back(log(fmax(xtmp, 1e-300)));
      lny.push_back(log(fmax(ytmp, 1e-300)));
    }
  }

public:
  InterpFunc(const string& file, bool lneval_ = true) : lneval(lneval_) {
    readfile(file);
    intp.SetData(x, y);
    lnintp.SetData(lnx, lny);
  }

  double xmin() const { return x[0]; }
  double xmax() const { return x[x.size() - 1]; }

  double operator()(double x) const { return lneval ? exp(lnintp.Eval(log(x))) : intp.Eval(x); }
};

int quadracture(const TString& fname, bool lneval)
{
  InterpFunc func(fname.Data(), lneval);
  ROOT::Math::Integrator counter(func, ROOT::Math::IntegrationOneDim::kADAPTIVE, 0, 1e-5, 0, ROOT::Math::Integration::kGAUSS51);
  cout << "Integrating result is: " << counter.Integral(func.xmin(), func.xmax()) << endl;
  return 0;
}
