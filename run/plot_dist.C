#include <iostream>
#include <sstream>
#include <fstream>
#include <vector>
#include <string>

#include "TString.h"
#include "TFile.h"
#include "TAxis.h"

#include "TH1F.h"
#include "TCanvas.h"

using namespace std;

int plot_dist(const TString &infile, int icol, int nbin, const TString &outname = "temp.eps", double rescale = 1.0) {
  if (icol == 0) {
    cout << "icol should be larger than zero" << endl;
    return 1;
  }

  TCanvas can("distribution", "distribution", 0, 0, 800,600);

  ifstream file(infile.Data());
  if (!file) {
    cout << "input file unexist!" << endl;
    return 2;
  }

  string line;
  vector <double> vec;
  vec.reserve(100000);

  double xmin = 0, xmax = 0;
  int nline = 1;
  for(; getline(file, line); nline++) {
    istringstream lstream(line);
    double tmpnum = 0;
    for (int i = 0; i < icol; i++) lstream >> tmpnum;

    if (nline == 1) {
      xmin = tmpnum; xmax = tmpnum;
    } else {
      xmin = (xmin < tmpnum ? xmin : tmpnum);
      xmax = (xmax > tmpnum ? xmax : tmpnum);
    }
    vec.push_back(tmpnum);
  }

  TH1F th(outname, outname + " distribution", nbin, xmin, xmax);
  for (int i = 0; i < nline; i++) th.Fill(vec[i], 1.0 / nline * nbin / (xmax - xmin) * rescale);

  th.Draw();
  can.Print(outname);

  return 0;
}
