*---------------------------------
* Analysis
*---------------------------------
set more off
cd E:\Dropbox\Teaching\ARE231\

* Read in data
* See data_description.docx for more on the data
use global_quantities, clear
merge 1:1 year using global_prices
drop _merge
sort year

* Calorie weights
gen kappa_maize=2204.622*(862/1316)*1690/(2000*365.25)
gen kappa_rice=2204.622*(1288/2178)*1590/(2000*365.25) 
gen kappa_soybeans=2204.622*(908/966)*1590/(2000*365.25)
gen kappa_wheat=2204.622*(489/798)*1615/(2000*365.25)

* Futures price index (use only maize, soybeans, and wheat because 
gen fut_price = (kappa_maize*C_fut_price +kappa_soybeans*S_fut_price + kappa_wheat*W_fut_price)/(kappa_maize+kappa_soybeans+kappa_wheat)

* Tell stata these are annual time series data
tsset year

* Create variables for use inregressions
gen ln_q=ln(prod)
gen ln_p=ln(l.fut_price/l.cpi)
gen ln_w=ln(yield_shock)

* Make cubic spline with 4 knots
mkspline trendsp = year, cubic nknots(4)

* Regressions; use Newey command so as to get heteroskedasticity and autocorrelation robust std errors
newey ln_q ln_p trendsp*, lag(1)
newey ln_q ln_p ln_w trendsp*, lag(1)
ivregress 2sls ln_q (ln_p=l.ln_w) ln_w trendsp*, first vce(hac nw 1)

