#include <iostream>

#include "TString.h"
#include "TFile.h"
#include "TAxis.h"

#include "TGraph.h"
#include "TGraphErrors.h"

using namespace std;

int root_convert(const TString &inname, const TString &outname, const TString &dataname, const TString &datatitle, const TString &xtitle, const TString &ytitle, int colnum) {
  TFile f(outname, "UPDATE");

  TGraph *gr = 0;

  if (2 == colnum) gr = new TGraph(inname, "%lg %lg");
  else if (3 == colnum) gr = new TGraphErrors(inname, "%lg %lg %lg");

  gr->SetName(dataname);
  gr->SetTitle(datatitle);

  gr->GetXaxis()->SetTitle(xtitle);
  gr->GetYaxis()->SetTitle(ytitle);

  f.WriteTObject(gr, dataname, "overwrite");

  f.Close();
  return 0;
}
