clear
clear matrix
set memory 300000
set more off
set logtype text

local dir1 "D:\张知遥\武汉大学\刘淼RA\Are Chinese Growth and Inflation Too Smooth Evidence from Engel Curves\Replication_1995-2022\data\"
local dir2 "D:\张知遥\武汉大学\刘淼RA\Are Chinese Growth and Inflation Too Smooth Evidence from Engel Curves\Replication_1995-2022\for_regressions\"
local dir3 "D:\张知遥\武汉大学\刘淼RA\Are Chinese Growth and Inflation Too Smooth Evidence from Engel Curves\Replication_1995-2022\output\"

local adjustment1996 "exp(-_b[_Yyear_1996]/_b[real_total_exp])"
forvalues i= 1997/2012 {
local year=`i'
local year2=`i'-1
local adjustment`year' "exp(-_b[_Yyear_`year']/_b[real_total_exp])/exp(-_b[_Yyear_`year2']/_b[real_total_exp])"
disp "`adjustment`year''"
}

local adjustment2014 "exp(-_b[_Yyear_2014]/_b[real_total_exp])"
forvalues i= 2015/2022 {
local year=`i'
local year2=`i'-1
local adjustment`year' "exp(-_b[_Yyear_`year']/_b[real_total_exp])/exp(-_b[_Yyear_`year2']/_b[real_total_exp])"
disp "`adjustment`year''"
}

local nlcom19952012 "nlcom (Adjustment1996: `adjustment1996') (Adjustment1997: `adjustment1997') (Adjustment1998: `adjustment1998') (Adjustment1999: `adjustment1999') (Adjustment2000: `adjustment2000') (Adjustment2001: `adjustment2001') (Adjustment2002: `adjustment2002') (Adjustment2003: `adjustment2003') (Adjustment2004: `adjustment2004') (Adjustment2005: `adjustment2005') (Adjustment2006: `adjustment2006') (Adjustment2007: `adjustment2007') (Adjustment2008: `adjustment2008') (Adjustment2009: `adjustment2009') (Adjustment2010: `adjustment2010') (Adjustment2011: `adjustment2011')(Adjustment2012:`adjustment2012')"
local nlcom20132022"nlcom (Adjustment2014:`adjustment2014')(Adjustment2015:`adjustment2015')(Adjustment2016:`adjustment2016')(Adjustment2017:`adjustment2017')(Adjustment2018:`adjustment2014')(Adjustment2019:`adjustment2019')(Adjustment2020:`adjustment2020')(Adjustment2021:`adjustment2021')(Adjustment2022:`adjustment2022')"

local control "sex_ratio avg_household_size unemployment childern elderly"

********************************
*    regresion 1995-2012       *
********************************

use "`dir1'Estimation Food.dta"
sort region year
keep if year < 2013

* Create year dummy
xi, prefix(_Y) i.year

* main regression
areg food_exp_share _Yyear* real_total_exp price_CPI_food `control' , absorb (region)
estimates store REG1
drop if year == 1995
matrix B=e(b)'
svmat B, name(DeltaReg1)
rename DeltaReg11 DeltaReg1

* calculate the annual bias of inflation, which is a nonlinear combination of coeffcients of regression
`nlcom19952012'

matrix B=r(b)'
svmat B, name(AdjustmentReg1)
rename AdjustmentReg11 AdjustmentReg1 /*The above three lines extract estimated annual bias from nlcom command*/
matrix V=(vecdiag(r(V)))'
svmat V, name(Variance)
gen SEAdjustmentReg1=sqrt(Variance) /*The above three lines extract standard errors of annual bias from the variance-covariance matrix*/

keep year Delta* Adjustment* SE*
keep if DeltaReg1~=. /*Keep only the relevant data*/
gen n=_n /*Create an index to be used in merging data*/
save "`dir2'temp", replace

* merge with the official inflation, calculate the adjusted inflation and its confidence intervals
keep if AdjustmentReg1~=.
tsset year
merge 1:1 year using "`dir1'Official Inflation"
drop _merge
keep if AdjustmentReg1~=.

gen AdjustedInflationReg1 = AdjustmentReg1*(1+OfficialInflation)-1
gen LBInflationReg1=AdjustedInflationReg1-invttail(e(df_r), 0.025)*SEAdjustmentReg1
gen UBInflationReg1=AdjustedInflationReg1+invttail(e(df_r), 0.025)*SEAdjustmentReg1 
keep year AdjustedInflationReg1 LBInflationReg1 UBInflationReg1

save "`dir2'Estimation Output Food", replace

********************************
*    regresion 2013-2022       *
********************************

* statsicial criteria changed in 2013
* estimate periods 1995-2012 and 2013-2022 seperatley, plot the results in the same graph

use "`dir1'Estimation Food"
sort region year
keep if year >= 2013

* Create year dummy
xi, prefix(_Y) i.year

areg food_exp_share _Yyear* real_total_exp price_CPI_food `control', absorb (region)
estimates store REG1
drop if year == 2013
matrix B=e(b)'
svmat B, name(DeltaReg1)
rename DeltaReg11 DeltaReg1

`nlcom20132022'

matrix B=r(b)'
svmat B, name(AdjustmentReg1)
rename AdjustmentReg11 AdjustmentReg1 /*The above three lines extract estimated annual bias from nlcom command*/
matrix V=(vecdiag(r(V)))'
svmat V, name(Variance)
gen SEAdjustmentReg1=sqrt(Variance) /*The above three lines extract standard errors of annual bias from the variance-covariance matrix*/

keep year Delta* Adjustment* SE*
keep if DeltaReg1~=. /*Keep only the relevant data*/
gen n=_n /*Create an index to be used in merging data*/
save "`dir2'temp", replace

keep if AdjustmentReg1~=.
tsset year
merge 1:1 year using "`dir1'Official Inflation"
drop _merge
keep if AdjustmentReg1~=.

gen AdjustedInflationReg2 = AdjustmentReg1*(1+OfficialInflation)-1
gen LBInflationReg2=AdjustedInflationReg2-invttail(e(df_r), 0.025)*SEAdjustmentReg1
gen UBInflationReg2=AdjustedInflationReg2+invttail(e(df_r), 0.025)*SEAdjustmentReg1 /* Am I right in this modification? what about the degree of freedom? */
keep year AdjustedInflationReg2 LBInflationReg2 UBInflationReg2

append using "`dir2'Estimation Output Food"

********************************
*           plot               *
********************************
tsset year
merge 1:1 year using "`dir1'Official Inflation"
drop _merge
tsset year
drop if year == 1995

graph twoway line AdjustedInflationReg1 LBInflationReg1 UBInflationReg1 AdjustedInflationReg2 LBInflationReg2 UBInflationReg2 OfficialInflation year, ///
lcolor(navy cranberry dkorange navy cranberry dkorange emerald) lpattern(solid dash dash solid dash dash solid) ///
legend(order(1 2 3 7) label(1 "Adjusted Inflation Reg1") label(2 "95% LowerBound") label(3 "95% UpperBound") label(7 "Official Inflation")) ///
title("Food Adjusted vs. Official Inflation") ///
subtitle("Urban Statistics in 1995-2022")
graph save "`dir3'AdjvsOff Inflation (Urban 1995-2022)", replace
