#include <iostream>
#include <vector>

#define CL_LIMITS
using namespace std;

#include "CL_limits_config.C"

const Double_t contour_level[] = { 2.2914, 6.1582, 11.6183, 19.332, 28.738 }; // for 0.682 0.954 0.997 0.9999366 0.999999425

const Double_t NHUGE = 1e300;
const Double_t deltamax = 100;

Double_t hist_foreach(TH2F* hist, void func(TH2F*, Int_t, Int_t, Double_t&), Double_t result = NHUGE)
{
  for (Int_t ix = 1; ix <= hist->GetXaxis()->GetNbins(); ix++)
    for (Int_t iy = 1; iy <= hist->GetYaxis()->GetNbins(); iy++)
      func(hist, ix, iy, result);

  return result;
}

void fill_hist(TH2F* hist, Int_t ix, Int_t iy, Double_t& value)
{
  Double_t x = hist->GetXaxis()->GetBinCenterLog(ix);
  Double_t y = hist->GetYaxis()->GetBinCenterLog(iy);

  hist->SetBinContent(ix, iy, limits_function(x, y));
}

void findmin(TH2F* hist, Int_t ix, Int_t iy, Double_t& value)
{
  Double_t val = hist->GetBinContent(ix, iy);
  if (value == NHUGE || value > val) value = val;
}

void substract_hist(TH2F* hist, Int_t ix, Int_t iy, Double_t& value)
{
  hist->SetBinContent(ix, iy,
                      hist->GetBinContent(ix, iy) - value);
}

vector<Double_t> get_bound(Double_t vmin, Double_t vmax, Double_t ngrid)
{
  Double_t factor = pow(vmax / vmin, 1.0 / ngrid);

  vector<Double_t> result; result.reserve(ngrid + 1);
  for (Double_t v = vmin; v <= vmax + 1e-5; v *= factor)
    result.push_back(v);

  return result;
}

void to_pow(TGraph* gr)
{
  for (Int_t i = 0; i < gr->GetN(); i++) {
    gr->GetX()[i] = pow(10, gr->GetX()[i]);
    gr->GetY()[i] = pow(10, gr->GetY()[i]);
  }
}

Double_t distance(Double_t x1, Double_t y1, Double_t x2, Double_t y2)
{
  return sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
}

// The graph is thinked as un_closed if the distance from the last point to the
// first point is farer than half of the points.
Bool_t un_closed(TGraph* gr)
{
  Int_t npoints = gr->GetN();
  Double_t *x = gr->GetX(),
           *y = gr->GetY();

  Double_t head_tail_distance = distance(x[0], y[0], x[npoints - 1], y[npoints - 1]);

  Int_t nfarer = 0;
  Int_t ncloser = 0;
  const Double_t critical_frac = 0.05;
  for (Int_t i = 1; i < npoints - 1; i++) {
    if (distance(x[0], y[0], x[i], y[i]) < head_tail_distance) ncloser++;
    else nfarer++;

    if (ncloser > (npoints - 2) * critical_frac) return true;
    if (nfarer > (npoints - 2) * (1 - critical_frac)) return false;
  }

  return ncloser / critical_frac > nfarer / (1 - critical_frac);
}

void search_outside_point(Double_t& x, Double_t& y)
{
  Double_t ds[4] = { log10(x / xmin) / log10(xmax / xmin),
    log10(xmax / x) / log10(xmax / xmin),
    log10(y / ymin) / log10(ymax / ymin),
    log10(ymax / y) / log10(ymax / ymin) };

  Double_t xs[4] = { xmin, xmax, x, x },
           ys[4] = { y, y, ymin, ymax };

  Int_t iter = 0;
  Double_t dmin = ds[0];
  for (Int_t i = 1; i < 4; i++)
    if (ds[i] < dmin) {
      dmin = ds[i];
      iter = i;
    }

  x = xs[iter]; y = ys[iter];
}

void complete_circle(TGraph* gr)
{
  Double_t x0 = gr->GetX()[0], y0 = gr->GetY()[0];
  search_outside_point(x0, y0);

  Double_t xn = gr->GetX()[gr->GetN() - 1], yn = gr->GetY()[gr->GetN() - 1];
  search_outside_point(xn, yn);

  vector<double> xvec, yvec;
  if (fmin(xn, x0) == xmin && fmax(xn, x0) == xmax) { // horizontal cross
    xvec.push_back(xmin); yvec.push_back(ymin);
    xvec.push_back(xmax); yvec.push_back(ymin);
  } else if (fmin(xn, x0) == xmin && fmin(yn, y0) == ymin) { // left bottom
    xvec.push_back(xmin); yvec.push_back(ymin);
  } else if (fmin(xn, x0) == xmin && fmax(yn, y0) == ymax) { // left top
    xvec.push_back(xmin); yvec.push_back(ymin);
    xvec.push_back(xmax); yvec.push_back(ymin);
    xvec.push_back(xmax); yvec.push_back(ymax);
  } else if (fmax(xn, x0) == xmax && fmin(yn, y0) == ymin) { // right bottom
    xvec.push_back(xmax); yvec.push_back(ymin);
  } else if (fmax(xn, x0) == xmax && fmax(yn, y0) == ymax) { // right top
    xvec.push_back(xmax); yvec.push_back(ymax);
  }

  gr->SetPoint(gr->GetN(), xn, yn);
  if (xn > x0) {
    for (int i = xvec.size() - 1; i >= 0; i--)
      gr->SetPoint(gr->GetN(), xvec[i], yvec[i]);
  } else {
    for (int i = 0; i < xvec.size(); i++)
      gr->SetPoint(gr->GetN(), xvec[i], yvec[i]);
  }
  gr->SetPoint(gr->GetN(), x0, y0);
}

void draw_contour(TList* list, Int_t i, TLegend* leg, vector<TGraph*>& result)
{
  static const Int_t MyPalette[6] = { kRed + 2, kGreen + 1, kYellow + 1, kYellow, kGray, kWhite };

  Int_t iter = 0;
  Bool_t to_complete;
  for (Int_t ig = 0; ig < list->GetSize(); ig++) {
    TGraph *gr = (TGraph*)list->At(ig)->Clone();

    to_complete = un_closed(gr);
    to_pow(gr);
    if (to_complete) complete_circle(gr);

    result.push_back(gr);
    gr->SetFillColor(MyPalette[i]);
    ostringstream lab;
    lab << i + 1 << "-#sigma";
    if (iter == 0) leg->AddEntry(gr, lab.str().c_str(), "f");
    iter++;
  }
}

void draw_line(const vector<vector<double> >& points) {
  TGraph *gr = new TGraph();
  for (const auto& p : points)
    gr->SetPoint(gr->GetN(), p[0], p[1]);
  gr->Draw("same l");
}

Int_t CL_limits()
{
  cerr << ">> initializing function" << endl;
  ini_function();
  vector<Double_t> xbounds = get_bound(xmin, xmax, xgrid),
    ybounds = get_bound(ymin, ymax, ygrid);

  TH2F *hist = new TH2F("distribution", "distribution", xgrid, &(xbounds[0]), ygrid, &(ybounds[0]));

  cerr << ">> filling histogram" << endl;
  hist_foreach(hist, fill_hist);
  cerr << ">> finding min chi2" << endl;
  Double_t minchi = hist_foreach(hist, findmin);
  cerr << ">> dealing histogram" << endl;
  hist_foreach(hist, substract_hist, minchi);

  Double_t bestx[1], besty[1];
  for (Int_t ix = 1; ix <= hist->GetXaxis()->GetNbins(); ix++)
    for (Int_t iy = 1; iy <= hist->GetYaxis()->GetNbins(); iy++)
      if (hist->GetBinContent(ix, iy) == 0) {
        bestx[0] = hist->GetXaxis()->GetBinCenterLog(ix);
        besty[0] = hist->GetYaxis()->GetBinCenterLog(iy);
      }
  TGraph bestgr(1, bestx, besty);

  TCanvas can("distribution", "distribution", 1600, 1200);
  can.SetLogx(); can.SetLogy();
  can.SetMargin(0.12, 0.03, 0.12, 0.03);
  TLegend* leg = new TLegend(0.16, 0.72, 0.3, 0.94);

#ifdef RAW_HIST
  hist->SetStats(0);
  hist->Draw("colz");
  draw_extra(bestx[0], besty[0], minchi);
  can.Print(outname);
  return 0;
#endif

#ifndef NSIGMA
#define NSIGMA 3
#endif
  hist->SetContour(NSIGMA, contour_level);
  vector<TGraph*> grs;

  hist->SetStats(0);
  hist->Draw("cont list");
  can.Update();
  TObjArray *contours = (TObjArray*)gROOT->GetListOfSpecials()->FindObject("contours");
  Int_t ncontours = contours->GetSize();
  for (Int_t icontour = ncontours - 1; icontour >= 0; icontour--)
    draw_contour((TList*)contours->At(icontour), icontour, leg, grs);

  can.Clear();
  for (auto gr : grs) gr->Draw("same f");

  bestgr.Draw("same p");
  bestgr.SetMarkerStyle(22);
  bestgr.SetMarkerSize(3);

  leg->AddEntry(&bestgr, "Best Fit", "p");

  hist->SetTitle("");
  hist->SetXTitle(xaxis);
  hist->SetYTitle(yaxis);
  hist->GetXaxis()->SetTitleSize(0.05);
  hist->GetYaxis()->SetTitleSize(0.05);
  hist->GetYaxis()->SetTitleOffset(1.15);
  hist->GetYaxis()->SetTickSize(0);
  hist->GetYaxis()->SetLabelSize(0);
  hist->GetXaxis()->SetTickSize(0);
  hist->GetXaxis()->SetLabelSize(0);

  TGaxis *Xaxis = new TGaxis(xmin, ymin, xmax, ymin, xmin, xmax, 505, "G");
  TGaxis *Yaxis = new TGaxis(xmin, ymin, xmin, ymax, ymin, ymax, 505, "G");
  Xaxis->SetTitle(xaxis);
  Yaxis->SetTitle(yaxis);
  Xaxis->SetTitleSize(0.05);
  Yaxis->SetTitleSize(0.05);
  Yaxis->SetTitleOffset(1.15);
  Xaxis->Draw();
  Yaxis->Draw();

  draw_line({ { xmin, ymax }, { xmax, ymax }, { xmax, ymin } });

  leg->Draw();

  draw_extra(bestx[0], besty[0], minchi);

  can.Print(outname);

  return 0;
}
