// test d3

cd "C:\Users\ku52502\Dropbox\Visualization\interactive\stata2d3"
clear
do stata2d3-9Sep2014.do

set obs 10
gen x=_n
gen s1=_n+4 in 1/2
gen s2=_n+3 in 3/4
gen l1=round(2*sin(x)+5,0.01)
gen l2=1+(((x-5)/2)^2)
gen str22 names = "Peter" in 1
replace names = "Mike" in 2
replace names = "Michael" in 3
replace names = "Bill" in 4

d3set , showhidetwoway("line1 line2 scatter3 scatter4")

d3 twoway (line l1 x, lcolor(steelblue) trans(0.6)) ///
		  (line l2 x, lwidth(2) trans(0.2)) ///
		  (scatter s1 x) ///
		  (scatter s2 x), ///
	replace htmltitle("My awesome graph") localjs ///
	xtitle("A variable") ytitle("Another variable") ///
	filename("test.html")

//#####################

sysuse auto, clear
sort mpg
replace price=price/1000
gen _mouseover = make + "<br>USD " + ///
					string(price,"%9.1f") + "<br>" + ///
					string(mpg,"%9.0f") + " MPG"
gen _d3twlab = "Line" in 1
replace _d3twlab = "Scatter" in 2
d3 twoway (line price mpg) (scatter price mpg), replace localjs ///
	htmltitle("1978 cars, in D3") ytitle("Price (1978 USD)") ///
	filename("test_auto.html")
