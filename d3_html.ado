*! Rob Grant, Tim Morris | 30aug2019

program define d3_html
version 14
syntax anything [, HTMLFile(string) ///
				   CLICKBelow(varname) ///
				   CLICKRight(varname) ///
				   CLICKPopup(varname) ///
				   HOVERBelow(varname) ///
				   HOVERRight(varname) ///
				   HOVERPopup(varname) ///
				   GROUPButtons(varname numeric) ///
				   LOcald3 ///
				   SVGVersion(integer 15) ///
				   Replace]
args svgfile


//	open svg file
tempname fi
tempname fo
file open `fi' using `"`svgfile'"', read text

// ********* need replace check here *********


file open `fo' using `"`htmlfile'"', write text replace

// start up the HTML file
file write `fo' "<!DOCTYPE html>" _n
file write `fo' "<html lang='en' dir='ltr'>" _n
file write `fo' "<head>" _n
file write `fo' "  <meta charset='utf-8'>" _n
file write `fo' "  <title></title>" _n
if "`locald3'"=="locald3" {
	file write `fo' "  <script type='text/javascript' src='d3.v3.min.js'></script>" _n
}
else {
	file write `fo' "  <script type='text/javascript' src='https://d3js.org/d3.v3.min.js'></script>" _n
}
file write `fo' "  <style media='screen'>" _n
file write `fo' "    p#righttext {" _n
file write `fo' "      position: relative;" _n
file write `fo' "      left: 5.5in;" _n
file write `fo' "      bottom: 2in;" _n
file write `fo' "    }" _n
file write `fo' "  </style>" _n
file write `fo' "</head>" _n _n

file write `fo' "<body>" _n

// copy SVG into the HTML file
file read `fi' svgline
local loopcount=1
local writing=0
//dis `"this line is: `svgline'"' // ***waypoint***
while r(eof)==0 {
	//dis `"this line is: `svgline'"'
	if substr(`"`svgline'"',1,4)=="<svg" {
		local writing=1
	}
	if `writing'==1 {
		file write `fo' `"`svgline'"' _n
	}
	local ++loopcount
	file read `fi' svgline
}

// write text under, right and buttons
file write `fo' "<p id='righttext'>&nbsp;</p>" _n
file write `fo' "<p id='undertext'>&nbsp;</p>" _n
if "`groupbuttons'"!="" {
	qui levelsof `groupbuttons', local(group_numbers)
	//local n_groups=r(r)
	foreach gn of local group_numbers {
		local group_label_`gn': label (`groupbuttons') `gn'
		file write `fo' "<button type='button' name='markercircle`gn'button' onclick='markercircle`gn'fun();'>`group_label_`gn''</button>" _n
	}
	file write `fo' "<button type='button' name='markercircleallbutton' onclick='markercircleallfun();'>All data</button>" _n
}

// start the JavaScript
file write `fo' "<script type='text/javascript'>" _n

// write arrays
foreach opt in clickbelow clickright clickpopup hoverbelow hoverright ///
							 hoverpopup {
	if "``opt''"!="" {
		local nobsminus1=_N-1
		file write `fo' _n "var `opt'=["
		forvalues i=1/`nobsminus1' {
			local tempdata=``opt''[`i']
			file write `fo' "'`tempdata''," _n
			if `svgversion'>14 {
				file write `fo' "'`tempdata''," _n // because of circle & border
			}
		}
		local i=`nobsminus1'+1
		local tempdata=``opt''[`i']
		if `svgversion'>14 {
			file write `fo' "'`tempdata''," _n // because of circle & border
		}
		file write `fo' "'`tempdata''];" _n
	}
}

// click/hover text display functionality
if "`clickbelow'"!="" {
	file write `fo' "d3.selectAll('circle').data(clickbelow)." _n
	file write `fo' "   on('click', function(d){" _n
	file write `fo' "       document.getElementById('undertext').innerHTML = d;" _n
	file write `fo' "})" _n _n
}
if "`hoverbelow'"!="" {
	file write `fo' "d3.selectAll('circle').data(hoverbelow)." _n
	file write `fo' "   on('hover', function(d){" _n
	file write `fo' "       document.getElementById('undertext').innerHTML = d;" _n
	file write `fo' "})" _n _n
}
if "`clickright'"!="" {
	file write `fo' "d3.selectAll('circle').data(clickright)." _n
	file write `fo' "   on('click', function(d){" _n
	file write `fo' "       document.getElementById('righttext').innerHTML = d;" _n
	file write `fo' "})" _n _n
}
if "`hoverright'"!="" {
	file write `fo' "d3.selectAll('circle').data(hoverright)." _n
	file write `fo' "   on('hover', function(d){" _n
	file write `fo' "       document.getElementById('righttext').innerHTML = d;" _n
	file write `fo' "})" _n _n
}

// add button functions
if "`groupbuttons'"!="" {
	foreach gn of local group_numbers {
		file write `fo' "function markercircle`gn'fun() {" _n
		file write `fo'	"  d3.selectAll('circle.markercircle').attr('stroke-opacity','0.2').attr('fill-opacity','0.2');" _n
		file write `fo'	"  d3.selectAll('circle.markergroup`gn'').attr('stroke-opacity','1').attr('fill-opacity','1');" _n
		file write `fo'	"}" _n _n
	}
	file write `fo' "function markercircleallfun() {" _n
	file write `fo' "d3.selectAll('circle.markercircle').attr('stroke-opacity','1').attr('fill-opacity','1');" _n
	file write `fo' "}" _n _n
}

file write `fo' "</script>" _n

// finish the HTML file
file write `fo' "</body>"
file write `fo' "</html>"

end


/* example run
clear
sysuse auto
cd "~/git/stata2d3"
d3_html "autotagged.svg", htmlfile("d3_html_test.html") svgv(16) clickright(make) groupbuttons(foreign)
