/*
Title: 0d_clean_deployment_allproviders.do
Purpose: Cleans FCC Form 477 data, and creates a dataset that includes all 
providers.
Author: Cole Campbell
Date Last Modified:05-04-2020
*/

* preferences 
	clear all
	cap log close
	set more off	
	
* directories - Mac
	global dirm "Your directory here"
	global raw "$dirm/raw"
	global output "$dirm/generated"
	
* ===================================================
* Begin
* ===================================================

* loop through each month
	foreach j in December June {
		
	* locals for different start years
		if "`j'"=="June" {
			local eyr=2014
		}
		if "`j'"=="December" {
			local eyr=2013
		}
		
		
	* loop through each year
		forvalues i=2010/`eyr' {
			local k=1
			
		* loop through blocks less than 2 miles, fixed wireless, and >2 miles	
			foreach file in "NBM-CBLOCK-CSV" "NBM-Wireless-CSV" "NBM-Address-Street" {
				
			* import data
				import delimited using ///
			"$data/All-NBM-CSV-`j'-`i'/`file'-`j'-`i'.csv", varnames(1)
			
			* make variables consistent with Form 477
				rename fullfipsid blockcode
				rename transtech techcode
				cap tostring blockcode, replace force format(%015.0f) // consistent formatting
				cap destring techcode-maxadup, replace	
				
			* drop satellite observations
				keep if techcode != 60 | techcode!=80				
			
			* save temporarily
				compress
				tempfile temp`k'
				save `temp`k'', replace		
				local k=`k'+1
			}

		* append file
			clear
			forvalues l=1/3 {
				append using `temp`l'', forace
			}
			cap destring techcode-maxadup, replace	

		* make date variable
			gen year = `i'
			gen mnth = `j'
			local name =mnth+year
			display "`name'"
			
			destring year, replace // make year variable numeric
			gen month = .
			replace month=6 if mnth=="June"
			replace month=12 if mnth=="December"
			
			gen date = ym(year,month)
			format date %tm
			
		* identify price cap carriers
			gen pricecap = regexm(hoconame, "(AT&T|Cincinnati Bell|Consolidated Communications|CenturyLink|FairPoint Communications|Frontier Communications|Hawaiian Telcom Communications|Micronesian Telecom|Verizon|Windstream Corporation|Windstream Holdings)")
		
		* replace blocks that are accidentally match from similar names
			replace pricecap=0 if hoconame=="Crossville Consolidated Communications, Inc."
			
		* calculate HHI assuming equal market share for each provider so shares will be identical
			egen num_prov = nvals(provname), by(blockcode)
			
		* construct tech speeds
			* dsl
			gen d_dsl = 0
			gen u_dsl = 0
			replace d_dsl = maxaddown if techcode==10 | ///
										 techcode==20
			replace u_dsl = maxadup if techcode==10 | ///
									   techcode==20
									   
			* cable
			gen d_cable = 0
			gen u_cable = 0
			replace d_cable = maxaddown if techcode==40 | ///
										   techcode==41
			replace u_cable = maxadup if techcode==40 | ///
										 techcode==41 
										 
			* fiber
			gen d_fiber = 0
			gen u_fiber = 0
			replace d_fiber = maxaddown if techcode==50
			replace u_fiber = maxadup if techcode==50
			
			* fixed wireless
			gen d_fixedwireless = 0
			gen u_fixedwireless = 0
			replace d_fixedwireless = maxaddown if techcode==70 | ///
												   techcode==71 
			replace u_fixedwireless = maxadup if techcode==70 | ///
												 techcode==71
			
			* copper
			gen d_copper = 0
			gen u_copper = 0
			replace d_copper = maxaddown if techcode==30
			replace u_copper = maxadup if techcode==30
			
			* powerline
			gen d_powerline = 0
			gen u_powerline = 0
			replace d_powerline = maxaddown if techcode==90
			replace u_powerline = maxadup if techcode==90
			
			* other
			gen d_other = 0
			gen u_other = 0
			replace d_other = maxaddown if techcode==0
			replace u_other = maxadup if techcode==0
			
		* make consumer and business variable
			cap tostring end_user_cat, replace
			if year>2011 {
				gen consumer = (end_user_cat=="1" | ///
								end_user_cat=="5" | ///
								end_user_cat==""  | ///
								end_user_cat=="." | ///
								end_user_cat=="None")
				gen business = (end_user_cat=="2" | ///
								end_user_cat=="3" | ///
								end_user_cat=="4")
			}
			else {
				gen consumer = (maxaddown!=.)
				gen business = (maxaddown!=.)
			}
			
			
		* collapse to the block level
			collapse (max) consumer business d_* u_* pricecap num_prov ///
			maxaddown maxadup, by(blockcode year month date)		
		}
	}

* append together
	clear
	foreach file in "NBM-June2011" "NBM-June2012" "NBM-June2013" "NBM-June2014" ///
	"NBM-December2011" "NBM-December2012" "NBM-December2013" {
		append using "$raw/deployment/`file'.dta"
	}
	
* compress and save
	compress
	save "$output/nbm_allproviders.dta", replace
