*---------------------------------
* Create prices dataset
*---------------------------------
set more off
cd E:\Dropbox\Research\Causality_in_Time_Series_Shared\RSdata_new\

/*
* Obtain futures price data from quandl; save daily prices for all contracts on the four commodities from 1959 through the present
local exch="CME"
foreach comm in C RR S W {    /* C=corn; RR=rough rice; S=soybeans; W=wheat  */
	local count=0
	forvalues yr =1959/2019 {
		foreach m in F G H J K M N Q U V X Z {   /* delivery months Jan through Dec  */
			capture quandl using temp, quandlcode(`exch'/`comm'`m'`yr') authtoken(eqR4U8soL92o1inrKMPD) clear replace  /* by using capture, I execute the quandl command but suppress output, including error messages. This prevents the program from crashing if the contract doesn't exist */
			if _rc==0 {					/* _rc=0 means that the quandl command executed without error  */
				local count=`count'+1
				keep date settle
				rename settle p`yr'`m'			/* settle is the price at the end of the day */
				local mo=cond("`m'"=="F",1,cond("`m'"=="G",2,cond("`m'"=="H",3,cond("`m'"=="J",4,cond("`m'"=="K",5,cond("`m'"=="M",6,cond("`m'"=="N",7,cond("`m'"=="Q",8, cond("`m'"=="U",9,cond("`m'"=="V",10,cond("`m'"=="X",11,12)))))))))))  /* mo denotes month 1-12 of contract */
				gen cont`yr'`m'=date("`mo'/1/`yr'","MDY")    /* create a variable to record the year and month of contract expiration  */
				format cont`yr'`m' %td	
				if `count'==1 {
					save `comm'fut, replace
				}
				else {
					quietly merge 1:1 date using `comm'fut
					drop _merge
				}
				sort date
				quietly save `comm'fut, replace
			}
		}
	}

	save `comm'fut, replace
	erase temp.dta
} 
*/

* Extract Nov/Dec futures contract prices for use in annual supply analysis
foreach comm in C RR S W  {
	use `comm'fut, clear
	
	* use Dec contract (delivery month = Z,12) if there exist prices for the 2016 Dec contract; otherwise use Nov contract. This will select Dec for C&W and Nov for RR&S
	capture summ p2016Z  
	if _rc==0 {
		local delmo="Z"
		local delmo1=12
		}
	else {
		local delmo="X"
		local delmo1=11
	}
	
	* aggregate from daily to monthly averages
	gen yr_mo=100*year(date)+month(date)
	keep yr_mo *`delmo'
	collapse *`delmo', by(yr_mo)
	sort yr_mo

	* dataset is presently one column for each contract; need to select relevant column for each year
	local count=0
	forvalues yr = 1959/2017 {
			capture summ p`yr'`delmo'
			if _rc==0 {
				local count=`count'+1
				quietly replace p`yr'`delmo'=. if p`yr'`delmo'==0
				if `count'==1 {
					gen `comm'_spot_cont=cont`yr'`delmo'
					gen `comm'_spot_price=p`yr'`delmo'
					
					gen `comm'_fut_cont=.
					gen `comm'_fut_price=.
				}
				else {
					quietly replace `comm'_fut_cont=cont`yr'`delmo' if (`comm'_spot_price[_n-1]!=.)&(`comm'_fut_price==.)
					quietly replace `comm'_fut_price=p`yr'`delmo' if (`comm'_spot_price[_n-1]!=.)&(`comm'_fut_price==.)

					quietly replace `comm'_spot_cont=cont`yr'`m' if (`comm'_spot_price==.)|(`comm'_spot_price==0)
					quietly replace `comm'_spot_price=p`yr'`m' if (`comm'_spot_price==.)|(`comm'_spot_price==0)
				}
				
			}
	}
	keep yr_mo `comm'_fut_cont  `comm'_fut_price `comm'_spot_cont  `comm'_spot_price

	* replace prices in Dec with prices in Jan if Dec prices are missing. This is for early years in sample when Dec futures did not trade in Dec of previous year (footnote 19 of Robers and Schlenker)
	gen mon=yr_mo-100*floor(yr_mo/100)
	replace `comm'_fut_cont=`comm'_spot_cont[_n+1] if `comm'_fut_cont==.&mon==12
	replace `comm'_fut_price=`comm'_spot_price[_n+1] if `comm'_fut_price==.&mon==12

	format `comm'_fut_cont %td
	format `comm'_spot_cont %td
	capture merge 1:1 yr_mo using global_prices
	capture drop _merge
	sort yr_mo
	save global_prices, replace
}


* aggregate from monthly to annual by selecting relevant cell
keep if mon==11|mon==12
	replace S_spot_cont=S_spot_cont[_n-1] if mon==12
	replace S_spot_price=S_spot_price[_n-1] if mon==12
	replace RR_spot_cont=RR_spot_cont[_n-1] if mon==12
	replace RR_spot_price=RR_spot_price[_n-1] if mon==12
keep if mon==12

gen year=floor(yr_mo/100)
drop mon yr_mo
save global_prices, replace

* merge CPI data 
import delimited CPI.csv, clear 
merge 1:1 year using global_prices
drop _merge
save global_prices, replace

