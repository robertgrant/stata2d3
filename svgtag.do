// parse and tag Stata SVG files

// add ids

// add Groups variable/matrix

/* add classes: xaxis, yaxis, xtitle, ytitle, xtick, ytick, xlabel, ylabel, gridline, 
				line, area, marker, markerlabel, rspike, 
				rcapupper, rcaplower
*/

/* add comment block containing Stata code that would read the coordinates of the data in:
		both the pixels and the original variable values, also the pixels for the plotregion
	add option to allocate different classes based on a variable, or possibly matrix
*/

/* we have to assume:
		the axes are not inside the plot region
		that there are ticks and labels, even if they are invisible
		the ticks and labels are in graphregion but not plotregion
		linear scales only
*/


capture program drop svgtag
program define svgtag, rclass
syntax anything [, Outputfile(string) Replace Metadata]
args inputfile


//arguments:
if `"`inputfile'"'=="" {
	dis as error "svgtag error: You must specify an input file"
	error 100
}
if `"`outputfile'"'=="" & "`replace'"=="" {
	dis as error "svgtag error: You must specify either an output filename or the replace option"
	error 100
}
if `"`outputfile'"'=="" & "`replace'"=="replace" {
	tempfile tempout
	local outputfile `"`tempout'"'
}

// check the inputfile exists
confirm file `"`inputfile'"'




tempname fi
tempname fo
file open `fi' using `"`inputfile'"', read text
file open `fo' using `"`outputfile'"', write text replace

local linecount 1
local rectcount 0
local circlecount 1
local circlepair 0
file read `fi' readline

// check that it's an svg file

while `"`readline'"'!="</svg>" {
	local writeverbatim=1 // indicator for writing unchanged at the end of the loop
	//dis "I'm writing line number `linecount': "
	//dis substr(`"`readline'"',1,20)
	
	// get Stata version
	if substr(`"`readline'"',1,21)=="<!-- This is a Stata " {
		local stataversion=substr(`"`readline'"',22,4) 
		// this assumes the format of that comment line doesn't change
	}

	// get canvas size and viewBox
	if substr(`"`readline'"',1,12)=="<svg version" {
		local widthpos1=strpos(`"`readline'"',"width=")+7
		local widthpos2=strpos(`"`readline'"',"height=")-1	
		local heightpos1=strpos(`"`readline'"',"height=")+8
		local heightpos2=strpos(`"`readline'"',"viewBox=")-1	
		local viewBoxpos1=strpos(`"`readline'"',"viewBox=")+9	
		local viewBoxpos2=strpos(`"`readline'"',"xmlns=")-1
		local returnwidth=substr(`"`readline'"',`widthpos1',`widthpos2'-`widthpos1'-1)
		local returnheight=substr(`"`readline'"',`heightpos1',`heightpos2'-`heightpos1'-1)
		local returnviewBox=substr(`"`readline'"',`viewBoxpos1',`viewBoxpos2'-`viewBoxpos1'-1)
	}
	
	// identify graphregion and plotregion, extract dimensions, and add class
	if substr(`"`readline'"',2,5)=="<rect" & `rectcount'==0 {
		local xpos1=strpos(`"`readline'"',"x=")+3
		local xpos2=strpos(`"`readline'"',"y=")-1	
		local ypos1=strpos(`"`readline'"',"y=")+3
		local ypos2=strpos(`"`readline'"',"width=")-1	
		local returngrx=substr(`"`readline'"',`xpos1',`xpos2'-`xpos1'-1)
		local returngry=substr(`"`readline'"',`ypos1',`ypos2'-`ypos1'-1)
		local widthpos1=strpos(`"`readline'"',"width=")+7
		local widthpos2=strpos(`"`readline'"',"height=")-1	
		local heightpos1=strpos(`"`readline'"',"height=")+8
		local heightpos2=strpos(`"`readline'"',"style=")-1	
		local returngrwidth=substr(`"`readline'"',`widthpos1',`widthpos2'-`widthpos1'-1)
		local returngrheight=substr(`"`readline'"',`heightpos1',`heightpos2'-`heightpos1'-1)
		local graphregion1=substr(`"`readline'"',1,`heightpos2')
		local graphregion2=substr(`"`readline'"',`heightpos2'+1,.)
		file write `fo' `"`graphregion1' class="graphregion" `graphregion2'"' _n
		local writeverbatim=0
		local ++rectcount
	}
	else if substr(`"`readline'"',2,5)=="<rect" & `rectcount'==1 {
		local xpos1=strpos(`"`readline'"',"x=")+3
		local xpos2=strpos(`"`readline'"',"y=")-1	
		local ypos1=strpos(`"`readline'"',"y=")+3
		local ypos2=strpos(`"`readline'"',"width=")-1	
		local returnprx=substr(`"`readline'"',`xpos1',`xpos2'-`xpos1'-1)
		local returnpry=substr(`"`readline'"',`ypos1',`ypos2'-`ypos1'-1)
		local widthpos1=strpos(`"`readline'"',"width=")+7
		local widthpos2=strpos(`"`readline'"',"height=")-1	
		local heightpos1=strpos(`"`readline'"',"height=")+8
		local heightpos2=strpos(`"`readline'"',"style=")-1	
		local returnprwidth=substr(`"`readline'"',`widthpos1',`widthpos2'-`widthpos1'-1)
		local returnprheight=substr(`"`readline'"',`heightpos1',`heightpos2'-`heightpos1'-1)
		local plotregion1=substr(`"`readline'"',1,`heightpos2')
		local plotregion2=substr(`"`readline'"',`heightpos2'+1,.)
		local pry2=`returnpry'+`returnprheight'
		local prx2=`returnprx'+`returnprwidth'
		file write `fo' `"`plotregion1' class="plotregion" `plotregion2'"' _n
		local writeverbatim=0
		local ++rectcount
	}

	// identify circles and add class and id
	/* ****** This assumes that v15+ has two circles per marker, so allocates the same id to each . 
	    ***** odd-then-even pair. If you turn off mborder, it will mess
		***** it up. Also, there should be no circles added for any other reason (at least, not
		***** an odd number of them).
	*/
	if substr(`"`readline'"',2,7)=="<circle" {
		local stylepos1=strpos(`"`readline'"',"style=")
		local circle1=substr(`"`readline'"',1,`stylepos1'-1)
		local circle2=substr(`"`readline'"',`stylepos1',.)
		file write `fo' `"`circle1' class="markercircle" id="circle`circlecount'" `circle2'"' _n
		if (substr("`stataversion'",1,2)=="14") {
			local ++circlecount		
		}
		if (substr("`stataversion'",1,2)!="14") & (`circlepair'==0) {
			local ++circlepair
		}
		else if (substr("`stataversion'",1,2)!="14") & (`circlepair'==1) {
			local --circlepair
			local ++circlecount
		}
		local writeverbatim=0
	}

	// identify lines, y-axis, x-axis, ticks and labels, add class and extract variable-to-pixel conversion
	// is it a <line?
	// extract x1, x2, y1, y2
	if substr(`"`readline'"',2,5)=="<line" {
		local x1pos1=strpos(`"`readline'"',"x1=")+4
		local x1pos2=strpos(`"`readline'"',"y1=")-1
		local y1pos1=strpos(`"`readline'"',"y1=")+4
		local y1pos2=strpos(`"`readline'"',"x2=")-1
		local x2pos1=strpos(`"`readline'"',"x2=")+4
		local x2pos2=strpos(`"`readline'"',"y2=")-1
		local y2pos1=strpos(`"`readline'"',"y2=")+4
		local y2pos2=strpos(`"`readline'"',"style=")-1	
		local x1=substr(`"`readline'"',`x1pos1',`x1pos2'-`x1pos1'-1)
		local x2=substr(`"`readline'"',`x2pos1',`x2pos2'-`x2pos1'-1)
		local y1=substr(`"`readline'"',`y1pos1',`y1pos2'-`y1pos1'-1)
		local y2=substr(`"`readline'"',`y2pos1',`y2pos2'-`y2pos1'-1)
		local stylepos1=strpos(`"`readline'"',"style=")
		local line1=substr(`"`readline'"',1,`stylepos1'-1)
		local line2=substr(`"`readline'"',`stylepos1',.)
		local ++linecount 
		// ****** do we count ALL lines, or just those that represent data?
		// does it lie on the plotregion boundary? it's an axis
		if `x1'==`returnprx' & `x2'==`returnprx' {
			file write `fo' `"`line1' class="y-axis" id="line`lineecount'" `line2'"' _n
			local writeverbatim=0
		}
		else if `y1'==`pry2' & `y2'==`pry2' {
			file write `fo' `"`line1' class="x-axis" id="line`lineecount'" `line2'"' _n
			local writeverbatim=0
		}
		// does it touch the plotregion boundary at one end? it's a tick
		else if (`x1'==`returnprx' & `x1'>`x2') | (`x2'==`returnprx' & `x1'<`x2') {
			file write `fo' `"`line1' class="y-tick" id="line`lineecount'" `line2'"' _n
			local writeverbatim=0
		}
		else if (`y1'==`pry2' & `y1'<`y2') | (`y2'==`pry2' & `y1'>`y2') {
			file write `fo' `"`line1' class="x-tick" id="line`lineecount'" `line2'"' _n
			local writeverbatim=0
		}
		// is it inside the plotregion? it's a line or a gridline
		// ******* we only check the x dimension. surely that's enough?
		else if (`x1'>`returnprx' & `x1'<`prx2' & `x2'>`returnprx' & `x2'<`prx2') {
			file write `fo' `"`line1' class="line" id="line`lineecount'" `line2'"' _n
			local writeverbatim=0
		} 
		else {
			local writeverbatim=1 // gridlines come out here
		}
	}
	
	
	// identify paths
		
		
	// detect xlabels and ylabels and use them to calculate a scale for each, converting between data and pixels
	// is it a <text?
	// is it between prx and grx, or pry and gry?
	
		
	
	if `writeverbatim'==1 {
		file write `fo' `"`readline'"' _n
	}
	

	file read `fi' readline
	local writeverbatim=1
	local ++linecount
}

file write `fo' "</svg>" _n _n

file close `fi'
file close `fo'

// replace option
if `"`outputfile'"'=="`tempout'" & "`replace'"=="replace" {
	if lower("$S_OS")=="windows" {
		shell del `"`inputfile'"'
		shell rename `"`outputfile'"' `"`inputfile'"'
	}
	else {
		shell rename -f `"`outputfile'"' `"`inputfile'"'
	}
}

// return metadata
return local stataversion "`stataversion'"
return local width "`returnwidth'"
return local height "`returnheight'"
return local viewBox "`returnviewBox'"
return local plotregionwidth "`returnprwidth'"
return local plotregionheight "`returnprheight'"
return local plotregionx "`returnprx'"
return local plotregiony "`returnpry'"
return local graphregionwidth "`returngrwidth'"
return local graphregionheight "`returngrheight'"
return local graphregionx "`returngrx'"
return local graphregiony "`returngry'"

end





// example run
svgtag "auto.svg", out("autotagged.svg")

