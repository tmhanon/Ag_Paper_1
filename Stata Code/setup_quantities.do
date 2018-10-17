*---------------------------------
* Create quantities dataset
*---------------------------------
set more off
cd E:\Dropbox\Teaching\ARE231\

import delimited FAOSTAT_data_2017.csv, clear 

replace element="area" if element=="Area harvested"
replace element="prod" if element=="Production"
replace item="maize" if item=="Maize"
replace item="rice" if item=="Rice, paddy"
replace item="soybeans" if item=="Soybeans"
replace item="wheat" if item=="Wheat"
rename areacode country
rename area country_str
drop if value==0
drop if value==.

gen item_element=item+"_"+element
keep country country_str year item_element  value
reshape wide value, i(year country country_str) j(item_element) string
sort country year
rename value* *


/* Dataset includes Hong Kong, Taiwan and Mainland China in both aggregated and disaggregated form. Keep only the aggregate. */
drop if country==41
drop if country==96
drop if country==214

merge m:1 country using hemisphere
drop _merge
replace northern=1 if country==276   /* new Sudan */
replace northern=1 if country==277   /* new South Sudan  */


bys country: gen N_obs=_N
* This is a list of countries without a full length panel
tab country_str if N_obs<54
****************Former USSR***********************
* FAO country code 228
replace country=228 if country_str=="Armenia" 
replace country=228 if country_str=="Azerbaijan" 
replace country=228 if country_str=="Belarus" 
replace country=228 if country_str=="Estonia" 
replace country=228 if country_str=="Georgia" 
replace country=228 if country_str=="Kazakhstan" 
replace country=228 if country_str=="Kyrgyzstan" 
replace country=228 if country_str=="Latvia" 
replace country=228 if country_str=="Lithuania" 
replace country=228 if country_str=="Republic of Moldova" 
replace country=228 if country_str=="Russian Federation" 
replace country=228 if country_str=="Tajikistan" 
replace country=228 if country_str=="Turkmenistan" 
replace country=228 if country_str=="Ukraine" 
replace country=228 if country_str=="Uzbekistan" 
* Call it "Former USSR" to indicate a continuous panel
replace country_str="Former USSR" if country==228

****************Former Yugoslav SFR***********************
* FAO country code 248
replace country=248 if country_str=="Croatia" 
replace country=248 if country_str=="Bosnia and Herzegovina" 
replace country=248 if country_str=="The former Yugoslav Republic of Macedonia" 
replace country=248 if country_str=="Slovenia" 
replace country=248 if country_str=="Serbia and Montenegro" 
replace country=248 if country_str=="Serbia" 
replace country=248 if country_str=="Montenegro" 

* Call it "Former Yugoslav SFR" to indicate a continuous panel
replace country_str="Former Yugoslav SFR" if country==248

****************Former Czechoslovakia***********************
* FAO country code 51
replace country=51 if country_str=="Czech Republic" 
replace country=51 if country_str=="Slovakia" 

* Call it "Former Czechoslovakia" to indicate a continuous panel
replace country_str="Former Czechoslovakia" if country==51

****************Belgium-Luxembourg***********************
* FAO country code 15
replace country=15 if country_str=="Belgium" 
replace country=15 if country_str=="Luxembourg" 

* Call it "Belgium-Luxembourg" to indicate a continuous panel
replace country_str="Belgium-Luxembourg" if country==15

****************Former Ethiopia***********************
* FAO country code 62
replace country=62 if country_str=="Ethiopia" 
replace country=62 if country_str=="Eritrea" 

* Call it "Former Ethiopia" to indicate a continuous panel
replace country_str="Former Ethiopia" if country==62


************** Combine countries ***********************
collapse (sum) *area *prod, by(country country_str northern year)

**************  Combine small countries by hemisphere. These are countries with less than 0.5% of global production of calories
gen small_country=0
replace small_country=1 if country!=9&country!=10&country!=16&country!=21&country!=28&country!=59&country!=68&country!=97&country!=100&country!=101&country!=102&country!=106&country!=110&country!=138&country!=165&country!=171&country!=183&country!=202&country!=203&country!=216&country!=223&country!=228&country!=231&country!=237&country!=248&country!=351

replace country_str="Rest of North" if small_country==1 & northern==1
replace country=888 if small_country==1 & northern==1
replace country_str="Rest of South" if small_country==1 & northern==0
replace country=999 if small_country==1 & northern==0

collapse (sum) *area *prod, by(country country_str northern year)


* Prepare for yield regressions to generate yield shocks
local crop "maize rice soybeans wheat"
foreach c of local crop {				
	gen `c'_yield=`c'_prod/`c'_area
	gen ln_`c'_yield=ln(`c'_yield)
	** replace ln_`c'_yield=0 if ln_`c'_yield==.
}

local country_list 9 10 16 21 28 59 68 97 100 101 102 106 110 138 165 171 183 202 203 216 223 228 231 237 248 351 888 999

*-------------------------------------------------------
* 3 knots
*-------------------------------------------------------
capture drop trendsp*
mkspline trendsp = year, cubic nknots(3)

gen yhat_maize_cntry=.
gen yhat_rice_cntry=.
gen yhat_soybeans_cntry=.
gen yhat_wheat_cntry=.

foreach cntry of local country_list {
	foreach c of local crop {				
		capture qui reg ln_`c'_yield trendsp* if country==`cntry'
		if _rc==0 {					/* _rc=0 means that the reg command executed without error  */
			 qui predict ghat_`c' if country==`cntry'
			 qui replace yhat_`c'_cntry=exp(ghat_`c'+e(rmse)^2/2) if country==`cntry'&ln_`c'_yield!=.
			 qui drop ghat*
		}
		qui replace yhat_`c'_cntry=0 if country==`cntry'&ln_`c'_yield==.
	}
}



* Kappa converts metric tons to calories
gen kappa_maize=2204.622*(862/1316)*1690/(2000*365.25)
gen kappa_rice=2204.622*(1288/2178)*1590/(2000*365.25) 
gen kappa_soybeans=2204.622*(908/966)*1590/(2000*365.25)
gen kappa_wheat=2204.622*(489/798)*1615/(2000*365.25)

* Create calorie-weighted commodity aggregates
gen area = (maize_area + rice_area + soybeans_area + wheat_area)/1000000
gen prod = (kappa_maize*maize_prod + kappa_rice*rice_prod + kappa_soybeans*soybeans_prod + kappa_wheat*wheat_prod)/1000000
gen yield_trend_sum = (kappa_maize*maize_area*yhat_maize_cntry + kappa_rice*rice_area*yhat_rice_cntry + kappa_soybeans*soybeans_area*yhat_soybeans_cntry + kappa_wheat*wheat_area*yhat_wheat_cntry)/1000000

save caloric_panel, replace


* Create global aggregates
collapse (sum) *_area *_prod area prod yield_trend_sum, by(year)
gen yield_trend = yield_trend_sum/area
gen yield_shock = prod/yield_trend_sum

save global_quantities, replace

