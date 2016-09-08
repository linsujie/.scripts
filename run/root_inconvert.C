#include <iostream>
#include <fstream>
#include <sstream>
#include <iomanip>

#include "TString.h"
#include "TFile.h"
#include "TAxis.h"

#include "TGraph.h"
#include "TGraphErrors.h"

using namespace std;

bool store_TGraphErrors(ofstream &out, TGraphErrors *gr) {
  out << "# \"" << gr->GetXaxis()->GetTitle() << "\"\t\"" << gr->GetYaxis()->GetTitle() << "\"\t\"error\"" << endl;
  for (Int_t i = 0; i < gr->GetN(); i++)
    out << gr->GetX()[i] << " " << gr->GetY()[i] << " " << gr->GetEY()[i] << endl;
  return true;
}

bool store_TGraph(ofstream &out, TGraph *gr) {
  out << "# \"" << gr->GetXaxis()->GetTitle() << "\"\t\"" << gr->GetYaxis()->GetTitle() << "\"" << endl;
  for (Int_t i = 0; i < gr->GetN(); i++)
    out << gr->GetX()[i] << " " << gr->GetY()[i] << endl;
  return true;
}

int root_inconvert(const TString &inname, const TString &outdir) {
  TFile f(inname, "READ");

  TList *list = f.GetListOfKeys();
  for (Int_t i = 0; i < list->GetEntries(); i++) {
    TString dataname = list->At(i)->GetName(),
            datatitle = list->At(i)->GetTitle();

    ofstream out(outdir + "/" + dataname + ".dat");
    if (datatitle != dataname) out << "#" << datatitle << endl;
    out << setiosflags(ios::scientific) << setprecision(6);

    const TString TGE = "TGraphErrors",
          TG = "TGraph";
    if (TGE == f.Get(dataname)->ClassName()) store_TGraphErrors(out, (TGraphErrors*)f.Get(dataname));
    else if (TG == f.Get(dataname)->ClassName()) store_TGraph(out, (TGraph*)f.Get(dataname));

    out.close();
  }

  return 0;
}
