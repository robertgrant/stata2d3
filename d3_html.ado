*! Rob Grant, Tim Morris | 11sep2019

program define d3_html
version 14
syntax anything [, HTMLFile(string) ///
				   CLICKBelow(varname) ///
				   CLICKRight(varname) ///
				   CLICKTip(varname) ///
				   HOVERBelow(varname) ///
				   HOVERRight(varname) ///
				   HOVERTip(varname) ///
				   MGroups(varname numeric) ///
				   LGroups(varname numeric) ///
				   LOcald3 ///
				   SVGVersion(integer 15) ///
				   Replace]
args svgfile


// open svg file
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
if "`mgroups'"!="" {
	qui levelsof `mgroups', local(group_numbers)
	//local n_groups=r(r)
	foreach gn of local group_numbers {
		local group_label_`gn': label (`mgroups') `gn'
		file write `fo' "<button type='button' name='markercircle`gn'button' onclick='markercircle`gn'fun();'>`group_label_`gn''</button>" _n
	}
	file write `fo' "<button type='button' name='markercircleallbutton' onclick='markercircleallfun();'>All data</button>" _n
}

// start the JavaScript
file write `fo' "<script type='text/javascript'>" _n

// add interaction
if "`clickbelow'"!="" | "`hoverbelow'"!="" | "`clickright'"!="" | "`hoverright'"!="" | "`hovertip'"!="" {

	// write arrays

	// count how many are given
/* #############  we do not yet account for the same variable appearing more than once;        #############
   #############  it probably makes no difference in the JavaScript but there's no accounting  #############
   #############  for every possible browser and future versions                               ############# */
	local n_interact_vars=0
	foreach opt in clickbelow clickright hoverbelow hoverright hovertip {
		if "``opt''"!="" {
			local ++n_interact_vars
		}
	}
	// start the statadata array
	if `svgversion'>14 { // repeat twice (for circles) in Stata 15+
		local arrayrep=2
	}
	else {
		local arrayrep=1
	}
	file write `fo' _n "var statadata=[" _n
	local nobs=_N
	forvalues i=1/`nobs' {   // a line for each observation...
		forvalues j=1/`arrayrep' { // ... repeated for Stata v15+
			local optcount=1
			file write `fo' "  {"
			foreach opt in clickbelow clickright hoverbelow hoverright hovertip {
				if "``opt''"!="" {
					// write an item for each interaction variable
					local tempdata=``opt''[`i']
					file write `fo' "`opt':'`tempdata''"
					if `optcount'<`n_interact_vars' {
						file write `fo' ", " // don't write comma after last variable
					}
					local ++optcount
				}
			}
			if `j'==`arrayrep' & `i'==`nobs' {
				file write `fo' "}];" _n _n // close the array at the end
			}
			else {
				file write `fo' "}," _n // or just close the element and move to the next
			}
		}
	}

// click/hover text display functionality
	file write `fo' "d3.selectAll('circle').data(statadata)" _n
	if "`clickbelow'"!="" {
		file write `fo' "   .on('click', function(d){" _n
		file write `fo' "       document.getElementById('undertext').innerHTML = d.clickbelow;" _n
		file write `fo' "     })" _n
	}
	if "`hoverbelow'"!="" {
		file write `fo' "   .on('mouseover', function(d){" _n
		file write `fo' "       document.getElementById('undertext').innerHTML = d.hoverbelow;" _n
		file write `fo' "     })" _n
		file write `fo' "   .on('mouseout', function(d){" _n
		file write `fo' "       document.getElementById('undertext').innerHTML = '';" _n
		file write `fo' "     })" _n
	}
	if "`clickright'"!="" {
		file write `fo' "   .on('click', function(d){" _n
		file write `fo' "       document.getElementById('righttext').innerHTML = d.clickright;" _n
		file write `fo' "     })" _n
	}
	if "`hoverright'"!="" {
		file write `fo' "   .on('mouseover', function(d){" _n
		file write `fo' "       document.getElementById('righttext').innerHTML = d.hoverright;" _n
		file write `fo' "     })" _n
		file write `fo' "   .on('mouseout', function(d){" _n
		file write `fo' "       document.getElementById('righttext').innerHTML = '';" _n
		file write `fo' "     })" _n
	}
// add tooltip
/* ##########  (In the shaolin temple,) there are three kinds of tooltip: SVG title elements,
   ##########  exotic HTML within SVG, and rect+text SVG. This implements SVG titles, which
   ##########  is the simplest but also the most unsatisfying visually. We ought to add at least
   ##########  exotic HTML as an option. */
	if "`hovertip'"!="" {
		file write `fo' "   .on('mouseover', function(d) {" _n
		// xPos and yPos will be used for exotic HTML & rect+text
		file write `fo' "      var xPos=parseFloat(d3.select(this).attr('cx'));" _n
		file write `fo' "      var yPos=parseFloat(d3.select(this).attr('cy'))-100;" _n
		file write `fo' "      inactivestroke = d3.select(this).style('stroke');" _n
		file write `fo' "      inactivefill = d3.select(this).style('fill');" _n
		file write `fo' "      d3.select(this).classed('activetooltip',true)" _n
// ############ include these fill & stroke styles as options ############
		file write `fo' "        .style('fill','#64ec23').style('stroke','#64ec23');" _n
		file write `fo' "      d3.select(this).append('title')" _n
		file write `fo' "        .text(d.hovertip);" _n
		file write `fo' "   })" _n
		file write `fo' "   .on('mouseout', function() {" _n
		file write `fo' "       d3.select(this).classed('activetooltip',false)" _n
		file write `fo' "         .style('fill',inactivefill).style('stroke',inactivestroke);" _n
		file write `fo' "   });" _n
	}
	file write `fo' ";" _n _n
}

// add button functions
if "`mgroups'"!="" {
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
