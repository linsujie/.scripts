#include <iostream>
#include <vector>
#include <set>

#define CL_LIMITS
using namespace std;

#include "CL_limits_config.C"

const Double_t contour_level[] = { 2.2914, 6.1582, 11.6183 }; // for 0.682 0.954 0.997

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
  for (Int_t i = 1; i < npoints - 1; i++) {
    if (distance(x[0], y[0], x[i], y[i]) < head_tail_distance) ncloser++;
    else nfarer++;

    if (ncloser > (npoints / 2 - 1)) return true;
    if (nfarer > (npoints / 2 - 1)) return false;
  }

  return ncloser > nfarer;
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

  if (xn > x0) {
    gr->SetPoint(gr->GetN(), xn, yn);
    if (yn == ymax) gr->SetPoint(gr->GetN(), xmax, ymax);
    if (xn == xmax || yn == ymax) gr->SetPoint(gr->GetN(), xmax, ymin);
    if (x0 == xmin) gr->SetPoint(gr->GetN(), xmin, ymin);
    gr->SetPoint(gr->GetN(), x0, y0);
  } else {
    gr->SetPoint(gr->GetN(), xn, yn);
    if (xn == xmin) gr->SetPoint(gr->GetN(), xmin, ymin);
    if (x0 == xmax || y0 == ymax) gr->SetPoint(gr->GetN(), xmax, ymin);
    if (y0 == ymax) gr->SetPoint(gr->GetN(), xmax, ymax);
    gr->SetPoint(gr->GetN(), x0, y0);
  }
}

void draw_contour(TList* list, Int_t i, TLegend* leg)
{
  static const Int_t MyPalette[4] = { kRed + 2, kGreen + 1, kYellow, kWhite };

  Int_t iter = 0;
  Bool_t to_complete;
  for (Int_t ig = 0; ig < list->GetSize(); ig++) {
    TGraph *gr = (TGraph*)list->At(ig)->Clone();

    to_complete = un_closed(gr);
    to_pow(gr);
    if (to_complete) complete_circle(gr);

    gr->Draw("same f");
    gr->SetFillColor(MyPalette[i]);
    ostringstream lab;
    lab << i + 1 << "-#sigma";
    if (iter == 0) leg->AddEntry(gr, lab.str().c_str(), "f");
    iter++;
  }
}

Int_t CL_limits()
{
  ini_function();
  vector<Double_t> xbounds = get_bound(xmin, xmax, xgrid),
    ybounds = get_bound(ymin, ymax, ygrid);

  TH2F *hist = new TH2F("distribution", "distribution", xgrid, &(xbounds[0]), ygrid, &(ybounds[0]));

  hist_foreach(hist, fill_hist);
  Double_t minchi = hist_foreach(hist, findmin);
  hist_foreach(hist, substract_hist, minchi);

  Double_t bestx[1], besty[1];
  for (Int_t ix = 1; ix <= hist->GetXaxis()->GetNbins(); ix++)
    for (Int_t iy = 1; iy <= hist->GetYaxis()->GetNbins(); iy++)
      if (hist->GetBinContent(ix, iy) == 0) {
        bestx[0] = hist->GetXaxis()->GetBinCenterLog(ix);
        besty[0] = hist->GetYaxis()->GetBinCenterLog(iy);
      }
  TGraph bestgr(1, bestx, besty);

  hist->SetContour(3, contour_level);

  TCanvas can("distribution", "distribution", 1600, 1200);
  can.SetLogx(); can.SetLogy();
  can.SetMargin(0.12, 0.03, 0.12, 0.03);
  TLegend* leg = new TLegend(0.16, 0.72, 0.3, 0.94);

  hist->SetStats(0);
  hist->Draw("cont list");
  can.Update();
  TObjArray *contours = (TObjArray*)gROOT->GetListOfSpecials()->FindObject("contours");
  Int_t ncontours = contours->GetSize();
  for (Int_t icontour = ncontours - 1; icontour >= 0; icontour--)
    draw_contour((TList*)contours->At(icontour), icontour, leg);

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

  TGaxis *xaxis = new TGaxis(xmin, ymin, xmax, ymin, xmin, xmax, 505, "G");
  TGaxis *yaxis = new TGaxis(xmin, ymin, xmin, ymax, ymin, ymax, 505, "G");
  xaxis->Draw();
  yaxis->Draw();

  leg->Draw();

  draw_extra();

  can.Print(outname);

  return 0;
}
