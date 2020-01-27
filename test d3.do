// test d3

cd "~/git/stata2d3"

// load progs
capture program drop d3_html
capture program drop d3_tag
capture program drop d3_make
capture program drop d3
do "d3_html.ado"
do "d3_tag.ado"
do "d3.ado"

// make data
sysuse auto, clear
gen hoverfacts = strofreal(mpg) + " MPG, $" + strofreal(price)

// test d3_tag and d3_html individually
scatter price mpg, scheme(s1mono)
graph export "auto.svg", replace
d3_tag "auto.svg", mgroups(foreign) out("autotagged.svg") replace
d3_html "autotagged.svg", htmlfile("d3_html_test.html") svgv(16) locald3 ///
  clickright(make) hovertip(hoverfacts) mgroups(foreign) replace


d3, clickright(make) hovertip(hoverfacts) mgroups(foreign) ///
    svgfile("auto2.svg") taggedsvgfile("autotagged2.svg") ///
	htmlfile("d3_html_test2.html") locald3 replace: ///
    scatter price mpg, scheme(s1mono)
