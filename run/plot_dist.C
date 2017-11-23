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

int plot_dist(const TString &infile, int icol, int nbin, const TString &outname = "temp.eps", double rescale = 1.0, double xmin = 0, double xmax = 0, double ymin = 0, double ymax = 0) {
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

  double xmin_ = 0, xmax_ = 0;
  int nline = 1;
  for(; getline(file, line); nline++) {
    istringstream lstream(line);
    double tmpnum = 0;
    for (int i = 0; i < icol; i++) lstream >> tmpnum;

    if (nline == 1) {
      xmin_ = tmpnum; xmax_ = tmpnum;
    } else {
      xmin_ = (xmin_ < tmpnum ? xmin_ : tmpnum);
      xmax_ = (xmax_ > tmpnum ? xmax_ : tmpnum);
    }
    vec.push_back(tmpnum);
  }

  if (xmax > xmin && ymax > ymin) {
    xmin_ = xmin; xmax_ = xmax;
  }

  TH1F th(outname, outname + " distribution", nbin, xmin_, xmax_);
  for (int i = 0; i < nline; i++) th.Fill(vec[i], 1.0 / nline * nbin / (xmax_ - xmin_) * rescale);

  if (xmax <= xmin || ymax <= ymin) th.Draw("hist E");
  else {
    can.DrawFrame(xmin, ymin, xmax, ymax, outname + " distribution");
    th.Draw("same hist E");
  }

  can.SetLogy();
  can.Print(outname);

  return 0;
}
