/*
Title: clean_form477.do
Purpose: Cleans FCC Form 477 data, and creates a dataset that includes all 
providers. Note that this can be reworked to use frames which is likely much better.
Author: Cole Campbell
Date Last Modified: 08-12-2022
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
	foreach j in jun dec {
		
	* locals for different start years
		if "`j'"=="jun" {
			local syr=2015
		}
		if "`j'"=="dec" {
			local syr=2014
		}
		
		
	* loop through each year
		forvalues i=`syr'/2019 {

		* import data
			import delimited using "$raw/deployment/fbd_us_without_satellite_`j'`i'", clear
			
		* convert blockcode to string for consistency
			tostring blockcode, replace force format(%015.0f)
			
		* make date variable
			gen year = `i'
			gen mnth = `j'
			local name =mnth+year
			display "`name'"
			
			destring year, replace // make year variable numeric
			gen month = .
			replace month=6 if mnth=="jun"
			replace month=12 if mnth=="dec"
			
			gen date = ym(year,month)
			format date %tm
			
		* identify blocks served by CAF II supported carriers
			gen pricecap = regexm(hocofinal, "(AT&T|Cincinnati Bell|Consolidated Communications|CenturyLink|FairPoint Communications|Frontier Communications|Hawaiian Telcom Communications|Micronesian Telecom|Verizon|Windstream Corporation|Windstream Holdings)")
			
		* replace blocks that are accidentally match from similar names
			replace pricecap=0 if hocofinal=="Crossville Consolidated Communications, Inc."
		
		* get number of providers
			egen num_prov = nvals(provider_id), by(blockcode date)
			
		* construct tech speeds
			* dsl
			gen d_dsl = 0
			gen u_dsl = 0
			replace d_dsl = maxaddown if techcode==10 | ///
										 techcode==11 | ///
										 techcode==12 | ///
										 techcode==20
			replace u_dsl = maxadup if techcode==10 | ///
									   techcode==11 | ///
									   techcode==12 | ///
									   techcode==20
			
			* cable
			gen d_cable = 0
			gen u_cable = 0
			replace d_cable = maxaddown if techcode==40 | ///
										   techcode==41 | ///
										   techcode==42 | ///
										   techcode==43
			replace u_cable = maxadup if techcode==40 | ///
										 techcode==41 | ///
										 techcode==42 | ///
										 techcode==43
										 
			* fiber
			gen d_fiber = 0
			gen u_fiber = 0
			replace d_cable = maxaddown if techcode==50
			replace u_cable = maxadup if techcode==50
			
			* fixed wireless
			gen d_fixedwireless = 0
			gen u_fixedwireless = 0
			replace d_fixedwireless = maxaddown if techcode==70
			replace u_fixedwireless = maxadup if techcode==70
			
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
			
		* get average down and upload speed
			egen avg_down = mean(maxaddown), by(blockcode date)
			egen avg_up = mean(maxadup), by(blockcode date)
			
		* collapse to the block date level (note that this process doesn't care about individual providers)
			collapse (max) consumer maxaddown maxadup business maxcirdown ///
				maxcirup d_* u_* pricecap num_prov, by(blockcode year month date)
			
		* save and append
			compress
			save "$raw/deployment/form477`name'_allproviders.dta", replace
		}
	}

* append files together
	clear
	forvalues i=2014/2019 {
		append using "$raw/deployment/form477dec`i'_allproviders.dta"
	}
	forvalues i=2015/2019 {
		append using "$raw/deployment/form477jun `i'_allproviders.dta"
	}
	
* save
	compress
	save "$output/form477_allproviders.dta", replace
