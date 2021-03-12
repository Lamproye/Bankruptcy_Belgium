/* Project: Belgian_bankruptcies: data processing and summary statistics 
Author: Lamproye 
Started on 22/1/2021
Last modified on: 8/3/2021   - by Lamproye
*/ 

clear all
set more off
global maindir "C:\Users\Gebruiker\Desktop\State_Aid_Covid\bankruptcy\Project\Data"
global Output  "C:\Users\Gebruiker\Desktop\State_Aid_Covid\bankruptcy\Project\Output"


/////////////////// Part I Data Processing 

// Stage 0) raw data: importing and saving 
// Number of registrations of firms per sector and employment class, with time in columns to see temporal evolution. 
* https://bestat.statbel.fgov.be/bestat/crosstable.xhtml?view=85280c84-005e-4998-9b20-5988e43439bc 
import delimited "$maindir\registrations_raw.csv"
save "$maindir/registrations_raw.dta", replace 

// Stage 1) consistent data: conversion to preferred format with a consistent schema with same info as raw data (no judgemental cleaning yet)
use "$maindir/registrations_raw.dta", clear 

// Data inspection registrations: sectie afdeling groep allewerknemersklassen niswerknemersklasse allebeschikbareperiodes jaar aantalbtwplichtige
foreach i in sectie afdeling groep allewerknemersklassen niswerknemersklasse allebeschikbareperiodes jaar aantalbtwplichtige{
tab `i'
}

duplicates report   // no duplicates

gen NACE_3 = substr(groep, 1, 2) + substr(groep, 4, 1)   // I do not set it to strings, otherwise I lose the starting 0, and NACE_3 is a categorical variable

save "$maindir/registrations_consistent.dta", replace 

// Stage 2) clean data: best possible representation of information 
use "$maindir/registrations_consistent.dta", clear 

// check missing variables: 
mdesc sectie afdeling groep allewerknemersklassen niswerknemersklasse allebeschikbareperiodes jaar aantalbtwplichtige
replace niswerknemersklasse = "Total" if niswerknemersklasse == ""   		// only consider totals: bankruptcies will be divided by this -> only lines with totals will matter

drop if jaar == .  // some line of the excel that served as a header, should not be there
drop if NACE_3 == "" & sectie != "Onbekende economische activiteit"			// total at a higher aggregation level 
drop if sectie == "Onbekende economische activiteit"
mdesc sectie afdeling groep allewerknemersklassen niswerknemersklasse allebeschikbareperiodes jaar aantalbtwplichtige
// there are missing variables in aantalbtwplichtige because there are not registrations in every employment class for every year in every sector

// throw away useless variables: no variation in it 
tab allewerknemersklassen
tab allebeschikbareperiodes
drop allewerknemersklassen allebeschikbareperiodes

replace aantalbtwplichtige = 0 if aantalbtwplichtige == . 

// the values of niswerknemersklasse in the registration data do not exactly correspond with the values in the bankruptcy data 
// need to merge employment class of 0 employees with 1-4 employees
replace niswerknemersklasse = "0 - 4 werknemers" if niswerknemersklasse == "Geen werknemer"
replace niswerknemersklasse = "0 - 4 werknemers" if niswerknemersklasse == "1-4 werknemers"
bys NACE_3 jaar niswerknemersklasse: egen merge_sum = total(aantalbtwplichtige) 
replace aantalbtwplichtige = merge_sum 
drop merge_sum
duplicates drop 

replace niswerknemersklasse = subinstr(niswerknemersklasse, " ", "", .)
tab niswerknemersklasse

save "$maindir/registrations_clean.dta", replace 

// Stage 3) derived data: contains only a subset of the information in the original data
use "$maindir/registrations_clean.dta", clear 

save "$maindir/registrations_derived.dta", replace 

// Stage 4) analysis sample: contains all the variable definitions and sample limitations needed for analysis
use "$maindir/registrations_derived.dta", clear  
sort NACE_3 niswerknemersklasse jaar 
isid NACE_3 niswerknemersklasse jaar 

// merge the registration data with the bankruptcy data. registration data is yearly and bankruptcy data monthly
merge 1:m NACE_3 niswerknemersklasse jaar using "$maindir/bankruptcy_month_derived.dta", gen(_m_bank)     // coming from the do file: Belgiqan_bankruptcies_processing_new
// _m_bank==1: in many sectors, there are no bankruptcies every month
// _m_bank==2: we do not have registration data for 2020-21 yet. if bankruptcy == 0, consistent. if not 0, either inconsistent, or there were as many bankruptcies as creations that year. 
sort NACE_3 niswerknemersklasse jaar month 
br if _m_bank==2 
br if _m_bank==2 & jaar != 2020 & jaar != 2021 
br if _m_bank==2 & jaar != 2020 & jaar != 2021 & aantalfaillissementen != 0 
br if niswerknemersklasse == "Total"
br
// with the current data, we do not use observations where _m_bank==2 
drop if _m_bank==2 
drop if _m_bank==1 
drop _m_bank

gen modate = ym(jaar, month) 
format modate %tm 

egen sector_id = group(NACE_3 niswerknemersklasse)

xtset sector_id  modate 

gen bank_ratio = aantalfaillissementen / aantalbtwplichtige   if aantalbtwplichtige != 0
replace bank_ratio = aantalfaillissementen   if aantalbtwplichtige == 0

// get the total amount of bankruptcies and registrations per time period, per sector
bys NACE_3 jaar: egen registrations_total = total(aantalbtwplichtige) 
bys NACE_3 jaar month: egen bankrupcty_total = total(aantalfaillissementen) 

gen bank_ratio_total = bankrupcty_total / registrations_total   if registrations_total != 0 
replace bank_ratio_total = registrations_total   if registrations_total == 0 

save "$maindir/registrations_bankruptcy_month_analysis.dta", replace 



/////////////////// Part II Summary Statistics 
use "$maindir/registrations_bankruptcy_month_analysis.dta", clear 

// some summary stats 
sum bank_ratio, d 
sum bank_ratio_total, d 

hist bank_ratio_total // most is 0 

// get the mean and the standard deviation 
bys NACE_3 niswerknemersklasse : egen bank_ratio_mean = mean(bank_ratio) 
bys NACE_3 : egen bank_ratio_total_mean = mean(bank_ratio_total) 

bys NACE_3 niswerknemersklasse : egen bank_ratio_sd = sd(bank_ratio) 
bys NACE_3 : egen bank_ratio_total_sd = sd(bank_ratio_total) 

// Compare sectors according to their rank 
tab bank_ratio_total_mean
tab  groep if bank_ratio_total_mean >= 0.0002308   // upper 5% of sectors in terms of total mean. can play with threshold to study the ranking

tab bank_ratio_total_sd
tab groep if bank_ratio_total_sd >=  .0005567   // upper 5% of sectors in terms of total mean. can play with threshold to study the ranking

// graphs for selected sectors: 
foreach i in 303 511 522 503 491 493 501   551 552 553 559   561 562 563   211 212   266 325  861 862 869   871 872 873 879  881 889   900 910 {
xtline bank_ratio_total if NACE_3 == "`i'"  , t(modate) i(groep) 
graph save "$Output/bank_ratio_total_`i'"  , replace 
}
// .jpg


xtline bank_ratio_total if NACE_3 == "910"  , t(modate) i(groep) 

xtline bank_ratio_total  , t(modate) i(groep) 


// telecom
xtline bank_ratio_total if NACE_3 == "611"  , t(modate) i(groep) 
xtline bank_ratio_total if NACE_3 == "612"  , t(modate) i(groep) 
xtline bank_ratio_total if NACE_3 == "613"  , t(modate) i(groep) 











