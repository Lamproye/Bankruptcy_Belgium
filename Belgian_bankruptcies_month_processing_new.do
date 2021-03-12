/* Project: Belgian_bankruptcies: data processing of bankruptcies
Author: Lamproye 
Started on 22/1/2021
Last modified on:    - by Lamproye
*/ 

clear all
set more off
global maindir "C:\Users\Gebruiker\Desktop\State_Aid_Covid\bankruptcy\Project\Data"
global Output  "C:\Users\Gebruiker\Desktop\State_Aid_Covid\bankruptcy\Project\Output"


/////////////////// Part I Data Processing 

// Stage 0) raw data: importing and saving 
// Number of bankruptcies per sector, per employment class, per month, with time in columns to see temporal evolution: 
* https://bestat.statbel.fgov.be/bestat/crosstable.xhtml?view=93736262-aba3-4841-bbed-13f5cefb1588 
import delimited "$maindir\bankruptcy_month_raw.csv"
save "$maindir/bankruptcy_month_raw.dta", replace 

// Stage 1) consistent data: conversion to preferred format with a consistent schema with same info as raw data (no judgemental cleaning yet)
use "$maindir/bankruptcy_month_raw.dta", clear 

rename grootteklassewerknemers niswerknemersklasse 

// Data inspection registrations: alleeconomischeactiviteiten sectie afdeling groep allegrootteklassen niswerknemersklasse jaar maand aantalfaillissementen 
foreach i in alleeconomischeactiviteiten sectie afdeling groep allegrootteklassen niswerknemersklasse jaar maand aantalfaillissementen {
tab `i'
}

duplicates report   // there are duplicates 
duplicates list 
duplicates drop 

gen NACE_3 = substr(groep, 1, 2) + substr(groep, 4, 1)   // I do not set it to strings, otherwise I lose the starting 0, and NACE_3 is a categorical variable

save "$maindir/bankruptcy_month_consistent.dta", replace 

// Stage 2) clean data: best possible representation of information
use "$maindir/bankruptcy_month_consistent.dta", clear 

// check missing variables: 
mdesc alleeconomischeactiviteiten sectie afdeling groep allegrootteklassen niswerknemersklasse jaar maand aantalfaillissementen 

drop if sectie == "" 	// (all sectors combined together during a given period) total at a higher aggregation level 
drop if maand == ""  // yearly total (higher aggregation level)
mdesc alleeconomischeactiviteiten sectie afdeling groep allegrootteklassen niswerknemersklasse jaar maand aantalfaillissementen 
// there are missing variables in aantalfaillissementen because there are not bankruptcies in every employment class for every year, every month in every sector
replace aantalfaillissementen = 0 if aantalfaillissementen == . 

// throw away useless variables: no variation in it 
tab alleeconomischeactiviteiten
tab allegrootteklassen
drop alleeconomischeactiviteiten allegrootteklassen

// adapt the month format 
gen month = substr(maand, 1, 3) 
replace month = "1"  if month == "Jan"
replace month = "2"  if month == "Feb"
replace month = "3"  if month == "Maa"
replace month = "4"  if month == "Apr"
replace month = "5"  if month == "Mei"
replace month = "6"  if month == "Jun"
replace month = "7"  if month == "Jul"
replace month = "8"  if month == "Aug"
replace month = "9"  if month == "Sep"
replace month = "10" if month == "Okt"
replace month = "11" if month == "Nov"
replace month = "12" if month == "Dec"
tab month
destring month, replace
drop maand // not necessary anymore

// the values of niswerknemersklasse in the registration data do not exactly correspond with the values in the bankruptcy data 
replace niswerknemersklasse = subinstr(niswerknemersklasse, " ", "", .)
tab niswerknemersklasse

save "$maindir/bankruptcy_month_clean.dta", replace 

// Stage 3) derived data: contains only a subset of the information in the original data
use "$maindir/bankruptcy_month_clean.dta", clear 

save "$maindir/bankruptcy_month_derived.dta", replace 



