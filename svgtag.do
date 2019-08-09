// parse and tag Stata SVG files

// add ids

/* add classes: xaxis, yaxis, xtitle, ytitle, xtick, ytick, xlabel, ylabel, gridline, 
				line, area, marker, markerlabel, rspike, 
				rcapupper, rcaplower
*/

/* add comment block containing Stata code that would read the coordinates of the data in:
		both the pixels and the original variable values, also the pixels for the plotregion
		
	add option to allocate different classes to markers and lines depending on their color
	add option to allocate different classes to markers and lines, given the number of 
		observations in each superimposed graph
*/

/* we have to assume:
		the axes are not inside the plot region
		that there are ticks and labels, even if they are invisible
		the ticks and labels are in graphregion but not plotregion
		linear scales only
*/

//cd "~/git/stata-svg"

capture program drop svgtag
program define svgtag, rclass
syntax anything [, Outputfile(string) Groups(namelist, min=1) Replace Metadata]
args inputfile


//arguments:
if `"`inputfile'"'=="" {
	dis as error "You must specify an input file"
	error 100
}
if `"`outputfile'"'=="" & "`replace'"=="" {
	dis as error "You must specify either an output filename or the replace option"
	error 100
}
if `"`outputfile'"'=="" & "`replace'"=="replace" {
	tempfile tempout
	local outputfile `"`tempout'"'
}

// check the inputfile exists
confirm file `"`inputfile'"'

// ######################## check the Groups matrix exists



tempname fi
tempname fo
file open `fi' using `"`inputfile'"', read text
file open `fo' using `"`outputfile'"', write text replace

local linecount 1
local rectcount 0
local circlecount 1
file read `fi' readline

// check that it's an svg file

while `"`readline'"'!="</svg>" {
	local writeverbatim=1 // indicator for writing unchanged at the end of the loop
	//dis "I'm writing line number `linecount': "
	//dis substr(`"`readline'"',1,20)
	
	// get Stata version
	if substr(`"`readline'"',1,21)=="<!-- This is a Stata " {
		local stataversion=substr(`"`readline'"',22,4) // this assumes the format of that comment line doesn't change
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
		file write `fo' `"`plotregion1' class="plotregion" `plotregion2'"' _n
		local writeverbatim=0
		local ++rectcount
	}

	// identify circles and add class and id
	if substr(`"`readline'"',2,7)=="<circle" {
		local stylepos1=strpos(`"`readline'"',"style=")
		local circle1=substr(`"`readline'"',1,`stylepos1'-1)
		local circle2=substr(`"`readline'"',`stylepos1',.)
		file write `fo' `"`circle1' class="markercircle" id="circle`circlecount'" `circle2'"' _n
		local ++circlecount
		local writeverbatim=0
	}

	// identify lines, y-axis, x-axis, ticks and labels, add class and extract variable-to-pixel conversion
	// is it a <line?
	// extract x1, x2, y1, y2
	if substr(`"`readline'"',2,5)=="<line" {
		local x1pos1=strpos(`"`readline'"',"x1=")+4
		local x1pos2=strpos(`"`readline'"',"y1=")-1
		local y1pos1=strpos(`"`readline'"',"y1=")+3
		local y1pos2=strpos(`"`readline'"',"x2=")-1
		local x2pos1=strpos(`"`readline'"',"x2=")+3
		local x2pos2=strpos(`"`readline'"',"y2=")-1
		local y2pos1=strpos(`"`readline'"',"y2=")+3
		local y2pos2=strpos(`"`readline'"',"style=")-1	
		local tempx1=substr(`"`readline'"',`x1pos1',`x1pos2'-`x1pos1'-1)
		dis "On line `linecount', I found x1 = "
		dis `"`tempx1'"'
	}

	// does it lie on the plotregion boundary? it's an axis
	// does it touch the plotregion boundary at one end? it's a tick
	// is it inside the plotregion? it's a line or a gridline
	// store it with class and consecutive id
	// is it a <text?
	// is it between prx and grx, or pry and gry?
	// is its location x-axis or y-axis? (what about double y-axes?)
	// store it with class and consecutive id
	
		
	
	if `writeverbatim'==1 {
		file write `fo' `"`readline'"' _n
	}
	
	// identify Stata comment and add our own (afterwards)
	if substr(`"`readline'"',1,20)=="<!-- This is a Stata" {
		if "`metadata'"=="metadata" {
			file write `fo' _n "<!-- Amended to add id, class and metadata using the svgtag command by Robert Grant and Tim Morris. -->" _n
		}
		else {
			file write `fo' _n "<!-- Amended to add id and class using the svgtag command by Robert Grant and Tim Morris. -->" _n
		}
	}

	file read `fi' readline
	local writeverbatim=1
	local ++linecount
}
/* more stuff after scanning through:
		look at all the ticks and labels/titles
		allocate some of the text to titles, captions etc
		associate ticks with labels
		generate conversion scale -- could be log
		Mata to convert matrices of pixel locations into variable values
		write as a JSON object or JS matrices
*/

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

