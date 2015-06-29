/* 	stata2d3
	Creates twoway line and scatter charts only.
   
	-d3parse- creates locals g_1, g_2, g_3 each containing command for 
		a superimposed graph, also `htmltitle', `filename' and `replace'
   
   To be added:
    d3set
	min-max filter
	clean up legend
	reconcile syntax command at beginning of -d3- with || twoway
	msize
	Add msizevar (cex) option for scatter
	lpattern should be easy...
    Ability to take mcolor RGB (# # #), or CMYK, or colorstyle*intensity
	cmissing(), sort() will require working with the data
	connect()
	hide/show all buttons
	onclick tooltip
	this requires line AND scatter at present; we have to drop all references
		to scatterdata or linedata if they are not there.
	didactic comments and the nocomments option
	expand into some other popular twoway graphs - some will require serset access
 	then add graph box and graph bar and others
	margins around the g object should expand to accommodate large values
	multiples (twoway ... , by(groupvar)) are not allowed - for now!
	What if a variable is %td or other time/date format? Can we extract the 
		%D-%M-%y type mask? Might need to write my own lookup table of these.
	Data could be both stset and d3set, allowing Kaplan-Meier plots from 
		the _d and _y and other variables.

Other notes:
	Writing each twoway graph as a separate data series is potentially 
		repetitive. It would be neat, but too hard at the JS end, to 
		combine graphs that differed only in look (lwidth, mcolor...). 
		There are a couple of approaches to making -d3- accept superimposed
		twoway graphs. This also affects how it is if- and in-able. 
	including htmltitle, filename, opacity and msizevar as options in -d3- 
	    is controversial (among me and myself) because it breaks the convention 
		of having only standard stata graph semantics and syntax. The best 
		approach, I now think, is to allow these options in d3set (so they 
		apply to all graphics that follow) or in individual -d3- commands 
		(which then take precedence over d3set).
	opacity() is not a Stata option. Values should be between 0 and 1.
	ytitle and xtitle can only be given as a global twoway option, if it is
		given inside any of the individual twoway commands it will be ignored.
	lcolor and/or mcolor can be set to "steelblue", which is not in Stata (s2color)
		but is a CSS color that has become such a cliche in online dataviz that 
		one would be cruel to deny its many fans. Its RGB value is (70,130,180) 
		or #4682B4.
	colorstyle is converted to RGBA values: "RGBA color values are supported 
		in IE9+, Firefox 3+, Chrome, Safari, and in Opera 10+". However, I have written 
		-colorstyle2hex- as a fallback; it will require a "hex" option in d3set which will then 
		cause any opacity options to be ignored.
	Show/hide interactivity is achieved by the less satisfying (than a Bostock
		join) approach of making SVG objects fully transparent. I learnt this
		from @d3noob. It's handy when you have lines (one SVG object per line) and
		scatters (one SVG object per observation). Maybe we'll be able to make it 
		neater in the future.
	The fact that -d3parse- splits up twoway graphs and -d3miniparse- the 
		constituents (and also other non-twoway graphs) means that you could
		superimpose a twoway with a non-twoway like:
		d3 scatter thisvar thatvar || graph box somevar, over(anothervar)
		In Stata the approach would be -addplot- although this is not always 
		possible. However in -d3- we cannot manipulate graphs made previously 
		so -addplot- can't be used. A similar problem arises for -graph combine-. 
		This could be a nice command, maybe -d3combine- to take fairly small 
		interactives and stick them together into a bigger "dashboard".
*/





// First for the subsidiary (yet jolly useful) colorstyle2hex & colorstyle2rgba

/* ####################################################################
   ###########################  colorstyle2hex  #######################
   #################################################################### */

/* This program takes a string (recognised Stata colorstyle)
   and returns a string containing the corresponding RGB hex code values
   Adapted from full_palette on SSC, by Nick Winter */
capture program drop colorstyle2hex
program define colorstyle2hex, rclass
syntax anything(name=colorinput)
tokenize `colorinput'
local colorstyle="`1'"
capture findfile color-`colorstyle'.style
 if _rc {
	di as err "{p 0 4 4}"
	di as err "color `colorstyle' not found{break}"
	di as err "Type -graph query colorstyle-"
	di as err "for a list of colornames."
	di as err "{p_end}"
	exit 111
}
local fn `"`r(fn)'"'
tempname hdl
file open `hdl' using `"`fn'"', read text
file read `hdl' line
while r(eof)==0 {
	tokenize `"`line'"'
	if "`1'"=="set" & "`2'"=="rgb" {
		tokenize `"`3'"'
		file close `hdl'
		continue, break
	}
	file read `hdl' line
}
// we now have RGB values in locals `1' `2' and `3'
forvalues i=1/3 {
	qui inbase 16 ``i''
	local hex`i'=r(base)
	if strlen("`hex`i''")==1 {
		local hex`i'="0"+"`hex`i''"
	}
}
// colhex is then what gets written to JS
local colhex="#"+"`hex1'"+"`hex2'"+"`hex3'"
/* need block here to deal with numlist RGB (including error
   messages if not three integers from 0 to 255) */
return local hex "`colhex'"
end







/* #####################################################################
   ###########################  colorstyle2rgba  #######################
   ##################################################################### */

// alpha=1 in all outputs but this is modified later
capture program drop colorstyle2rgba
program define colorstyle2rgba, rclass
syntax anything(name=colorinput)
tokenize `colorinput'
local colorstyle="`1'"
capture findfile color-`colorstyle'.style
 if _rc {
	di as err "{p 0 4 4}"
	di as err "color `colorstyle' not found{break}"
	di as err "Type -graph query colorstyle-"
	di as err "for a list of colornames."
	di as err "{p_end}"
	exit 111
}
local fn `"`r(fn)'"'
tempname hdl
file open `hdl' using `"`fn'"', read text
file read `hdl' line
while r(eof)==0 {
	tokenize `"`line'"'
	if "`1'"=="set" & "`2'"=="rgb" {
		tokenize `"`3'"'
		file close `hdl'
		continue, break
	}
	file read `hdl' line
}
// we now have RGB values in locals `1' `2' and `3'
return local red `1'
return local green `2'
return local blue `3'
return local alpha 1
end










/* #############################################################
   ###########################  d3parse  #######################
   ############################################################# */

/* Should create:
	r(ngraphs) with number of overlapping graphs
	r(g_*) containing parsed commands 
   As of 4 September 2014, d3parse switched to using _parse commands 
   The effect of this is that the global options go into their own returned
	object at r(g_opt). This fixes the problem of quotes inside options.
	
	Note that if you supply -graph...- command to d3parse you will get
	`anything' back unaltered in r(g_1)
*/
capture program drop d3parse
program d3parse, rclass
version 11

// find and remove -twoway-
local anything="`0'" 
local rawcommand="`0'" // continues to be available as the raw command
gettoken firstword therest : anything, parse(" (|")
if substr("`firstword'",1,2)=="tw" {
	local anything="`therest'"
} // `anything' now contains the command we want

_parse expand g c: anything

return local ngraphs=`g_n'
forvalues i=1/`g_n' {
	return local g_`i' "`g_`i''"
}
return local g_opt="`c_op'"
return local g_if="`c_if'"
return local g_in="`c_in'"


end
















/* #######################################################################
   #############################  d3miniparse  ###########################
   ####################################################################### */
   
// This is used for individual twoway commands, and perhaps stuff like -graph box- too
capture program drop d3miniparse
program d3miniparse, rclass
version 11
syntax anything [, *] // if and in are not included at present, but will be later
tokenize `anything'
// rename all these macros
local tokens=1
while "`*'" != "" {
	local c_`tokens'="`1'"
	macro shift
	local tokens=`tokens'+1
}
// check that variables `c_2' and `c_3' exist
confirm variable `c_2' `c_3'
// and c_4 too if it exists, e.g. rcap
if "`c_4'"!="" {
	confirm variable `c_4'
}

/* Check that the command is valid in stata2d3. The block that follows 
	will gradually expand.
   It will need to accommodate two-word commands like -graph box-
   or -twoway (line...- and of course brackets will have to be stripped out too.
*/
if "`c_1'"!="line" & substr("`c_1'",1,2)!="sc" {
	dis as error "`c_1' is not recognised as a graph command in stata2d3."
	dis as error "Either it is not a valid Stata graph command, or it"
	dis as error "has not yet been programmed in stata2d3. Eventually,"
	dis as error "all Stata graph commands will be included."
	dis as error "---"
	error 199
}

tokenize `options'
local tokens=1
while "`*'" != "" {
	local opt_`tokens'="`1'"
	macro shift
	local tokens=`tokens'+1
} 
local noptions=`tokens'-1
return local c_1 "`c_1'"
return local c_2 "`c_2'"
return local c_3 "`c_3'"
if "`c_4'"!="" {
	return local c_4 "`c_4'"
	return local n_c=4 // how many words are in the command 
}
else {
	return local n_c=3
	}
return local noptions=`noptions'
forvalues i=1/`noptions' {
	return local opt_`i' "`opt_`i''"
}

end













/* ###########################################################
   ###########################  d3set  #######################
   ########################################################### */

/* interactivity options:
		show / hide twoway components (tickboxes)
		highlight twoway components (tickboxes)
		filter xmin, xmax or ymin, ymax with sliders or text input
		string variable for onclick per datum
		string variable for mouseover per datum
		string for onclick/mouseover
		localjs
   aesthetic options:
		transition time in milliseconds
		opacity from 0 to 1
		htmltitle
		filetitle
		nocomments
*/

capture program drop d3set
program define d3set

syntax [anything], [SHOWHIDETWoway(namelist) ///
				 SHOWHIDECONDition(namelist min=1) /// 
				 Filter(varlist) LOCALJS NOCOMMENTS ///
				 ONCLick(varname) ONHOver(varname) ///
				 TRANSITion(integer 600) OPacity(real 1) ///
				 HEX CLEAR REPLACE] 
if "`clear'"=="clear" {
	capture drop _d3*
	dis as result "d3setting has been removed from data"
	exit
}
if "`replace'"=="replace" {
	capture drop _d3*
}
// is it already d3set?
capture confirm variable _d3opa // one of the variables that d3set always makes
if _rc==0 & "`replace'"=="" {
	dis as error "Data are already d3set"
	error 1
}
if `opacity'<0 | `opacity'>1 {
	dis as error "Opacity option must be between 0 and 1, inclusive"
	error 1
	exit
}
if "`showhidetwoway'"!="" {
	tokenize `showhidetwoway'
	local tokens=1
	while "`*'" != "" {
		local twlab_`tokens'="`1'"
		macro shift
		local tokens=`tokens'+1
	} 
	local n_twlab=`tokens'-1
	if _N<`n_twlab' {
		set obs `n_twlab' // beware! this will introduce new missing rows
	}
	local maxlen_twlab=1 // find the longest twlab string
	forvalues i=1/`n_twlab' {
		local maxlen_twlab=max(`maxlen_twlab',length("`twlab_`i''"))
	}
	qui gen str`maxlen_twlab' _d3twlab=""
	forvalues i=1/`n_twlab' {
		qui replace _d3twlab="`twlab_`i''" in `i'
	}
}
if "`onhover'"!="" {
	qui gen _d3onhover=`onhover'
}
if "`onclick'"!="" {
	qui gen _d3onclick=`onclick'
}
qui gen str10 _d3nocomments=""
if "`nocomments'"!="" {
	qui replace _d3nocomments="nocomments" in 1
}
qui gen str7 _d3localjs=""
if "`localjs'"!="" {
	qui replace _d3localjs="localjs" in 1
}
qui gen _d3transit=`transition' in 1
qui gen _d3opa=`opacity' in 1
end


















/* #################################################################
   ################################  d3  ###########################
   ################################################################# */

// and now the main d3 prefix command
capture program drop d3
program d3
version 11

syntax anything [, htmltitle(string) localjs filename(string) ///
				   replace YTItle(string) XTItle(string) *]
/* at present this syntax command causes trouble if we try || style
	twoway graphs */
local rawcommand="`anything'" // continues to be available as the raw command

// what has d3set provided?
local useonhover=0
capture confirm variable _d3onhover
if _rc==0 {
	local useonhover = 1
}
capture confirm variable _d3nocomments
if _rc==0 {
	local nocomments=_d3nocomments[1]
}
else {
	local nocomments=""
}
capture confirm variable _d3localjs
if _rc==0 {
	local localjs=_d3localjs[1]
}
else {
	local localjs=""
}
	
local transition=_d3transit[1]
local opacity=_d3opa[1]

// deal with global options
if "`filename'"=="" {
	local filename="index.html" // default filename
}
// check whether filename already exists
if "`replace'"!="replace" {
	capture confirm file "`filename'"
	if _rc==0 {
		dis as error "`filename' already exists. Please use the -replace- option if you want to overwrite it."
		error 1
	}
}
// ytitle and xtitle
local ixtitle="x"
local iytitle="y" // these get replaced if all graphs have same xvar / yvar
local stopxtitle=0
local stopytitle=0 // these flag whether to stop looking for xtitle/ytitle
if "`xtitle'"!="" {
	local stopxtitle=1
	local ixtitle="`xtitle'"
}
if "`ytitle'"!="" {
	local stopytitle=1
	local iytitle="`ytitle'"
}

// is this a twoway graph? If so, drop the twoway word, then call d3parse
gettoken firstword therest : anything, parse(" (|")
if substr("`firstword'",1,2)=="tw" | ///
   substr("`firstword'",1,2)=="sc" | ///
   substr("`firstword'",1,4)=="line" {
	d3parse `rawcommand'
	local ngraphs=r(ngraphs)
	forvalues i=1/`ngraphs' {
		local g_`i'=r(g_`i')
	}
	local g_opt=r(g_opt)
	local g_if=r(g_if) // at present, if and in are not used...
	local g_in=r(g_in)
	
	// now loop over r(ngraphs) and parse r(g_*)
	local nline=0
	local nscatter=0
	forvalues i=1/`ngraphs' {
		// global option, or from d3set - can be replaced within each graph
		local opacity_`i' = `opacity' 
		d3miniparse `g_`i''
		forvalues j=1/3 {
			local g_`i'_`j' = r(c_`j')
		}
		local n_c=r(n_c)
		if `n_c'==4 { // if there is a fourth word, i.e. 3 variables like rcap
			local g_`i'_4 = r(c_4)
		}
		// look for xvar and yvar that can be used as xtitle and ytitle
		// (this matches Stata default axis-labelling)
		if `stopxtitle'==0 {
			if `i'==1 {
				local ixtitle = "`g_`i'_3'"
			}
			else if "`g_`i'_3'" != "`ixtitle'" {
				local ixtitle = ""
				local stopxtitle = 1
			}
		}
		if `stopytitle'==0 {
			if `i'==1 {
				local iytitle = "`g_`i'_2'"
			}
			else if "`g_`i'_2'" != "`iytitle'" {
				local iytitle = ""
				local stopytitle = 1
			}
		}
		// count the lines and scatters, and keep matrices of the g_i numbers
		if "`g_`i'_1'"=="line" {
			local ++nline
			if `nline'==1 {
				matrix lineorder=(`i')
			}
			else {
				matrix lineorder=(lineorder,`i')
			}
		}
		if substr("`g_`i'_1'",1,2)=="sc" {
			local ++nscatter
			if `nscatter'==1 {
				matrix scatterorder=(`i')
			}
			else {
				matrix scatterorder=(scatterorder,`i')
			}
		}
		local noptions_`i'=r(noptions)
		forvalues j=1/`noptions_`i'' {
			local opt_`i'_`j' = r(opt_`j')
		}
		local ilwidth_`i' = 1 // default
		local icolor_`i' = "default" // default for both mcolor & lcolor
		
		/* loop through options for graph i and allocate them 
		   to known graphing options */
		forvalues j=1/`noptions_`i'' {
		
		// lwidth option
			if substr("`opt_`i'_`j''",1,2)=="lw" {
				local temp = `j'+1
				local lw2 = "`opt_`i'_`temp''"
				capture confirm number `lw2'
				if !_rc {
					local ilwidth_`i'=`lw2' 
		/* this translates lwidth(#) to pixels, perhaps looking a bit
			different to the Stata graph that would result */
				}
				else if "`lw2'"=="vvthin" local ilwidth_`i'=0.1
				else if "`lw2'"=="vthin" local ilwidth_`i'=0.2
				else if "`lw2'"=="thin" local ilwidth_`i'=0.4
				else if "`lw2'"=="medthin" local ilwidth_`i'=0.6
				else if "`lw2'"=="medium" local ilwidth_`i'=1
				else if "`lw2'"=="thick" local ilwidth_`i'=2
				else if "`lw2'"=="vthick" local ilwidth_`i'=3
				else if "`lw2'"=="vvthick" local ilwidth_`i'=4
				else if "`lw2'"=="vvvthick" local ilwidth_`i'=5
				else {
					dis as error "lwidth option was not recognised"
					error 1
				}
			}
			else if substr("`opt_`i'_`j''",1,3)=="opa" {
				local temp = `j'+1
				local opacity_`i' = `opt_`i'_`temp''
			}
			else if substr("`opt_`i'_`j''",1,2)=="lc" | substr("`opt_`i'_`j''",1,2)=="mc" {
				local temp = `j'+1
				if "`opt_`i'_`temp''" == "steelblue" {
					local icolor_`i' = "'rgba(70,130,180,`opacity_`i'')'"
				}
				else {
					colorstyle2rgba "`opt_`i'_`temp''"
					local tempred=r(red)
					local tempgreen=r(green)
					local tempblue=r(blue)
					local icolor_`i' = "rgba(`tempred',`tempgreen',`tempblue',`opacity_`i'')"
				}
			}
/* Could do something here to allow xtitle and ytitle within individual
   twoway commands, but the quotes cause some confusion inside the `anything' macro
			else if substr("`opt_`i'_`j''",1,3)=="yti" {
				local temp=`j'+1
				local stopytitle=1
				local iytitle = "`opt_`i'_`temp''"
			}
			else if substr("`opt_`i'_`j''",1,3)=="xti" {
				local temp=`j'+1
				local stopxtitle=1
				local ixtitle = "`opt_`i'_`temp''"
			} */

		}
	}
}


// one day we could allow other styles; going with s2color for now.
local s2color_1 = "'rgba(26,71,111,1)'"
local s2color_2 = "'rgba(144,53,59,1)'"
local s2color_3 = "'rgba(85,117,47,1)'"
local s2color_4 = "'rgba(227,126,0,1)'"
local s2color_5 = "'rgba(110,142,132,1)'" 
local s2color_6 = "'rgba(193,5,52,1)'" 
local s2color_7 = "'rgba(147,141,210,1)'"
local s2color_8 = "'rgba(202,194,126,1)'"
local s2color_9 = "'rgba(160,82,45,1)'" 
local s2color_10 = "'rgba(123,146,168,1)'"
local s2color_11 = "'rgba(45,109,102,1)'" 
local s2color_12 = "'rgba(156,136,71,1)'" 
local s2color_13 = "'rgba(191,161,156,1)'" 
local s2color_14 = "'rgba(255,210,0,1)'" 
local s2color_15 = "'rgba(217,230,235,1)'" 
local s2color_16 = "'rgba(96,96,96,1)'" 
// use these if icolor has not been set
forvalues i=1/`ngraphs' {
	if "`icolor_`i''"=="default" {
		local current_twcolorindex= mod((`i'-1),16)+1
		local icolor_`i' = "`s2color_`current_twcolorindex''"
	}
// if opacity is specified, then change alpha
	if `opacity_`i''!=1 {
		local icolor_prealpha = substr("`icolor_`i''",1,length("`icolor_`i''")-4)
		local icolor_`i' = "`icolor_prealpha',`opacity_`i'')'"
	}
}



// else if substr("`firstword'",1,2)=="gr" ........ try d3miniparse

// else error



// capture block begins here to ensure that the file handle is always closed at the end
capture noisily {
// passes replace as an option
file open myfile using `filename', write text `replace'

// BEWARE! USING SEMICOLON DELIMITER TO REDUCE FILE WRITE COMMANDS
#delimit ; 
	file write myfile "<!DOCTYPE html>" _n;
	file write myfile "<html>" _n;
	file write myfile "<head>" _n;
    	file write myfile _tab "<meta charset='utf-8'>" _n;
		file write myfile _tab "<meta name='description' content='Made using Stata2D3 (robertgrantstats.co.uk/software)'>" _n;
    	file write myfile _tab "<title>`htmltitle'</title>" _n;
		if "`localjs'"=="localjs" {;
	    	file write myfile _tab "<script type='text/javascript' src='d3.v3.min.js'></script>" _n _n;
		};
		else {;
			file write myfile _tab "<script type='text/javascript' src='http://d3js.org/d3.v3.js'></script>" _n _n;
		};
		file write myfile _tab "<style>" _n;
			file write myfile _tab(2) "body { " _n;
				file write myfile _tab(3) "font-family: 'helvetica'; " _n;
			file write myfile _tab(2) "}" _n;
			file write myfile _tab(2) "path { " _n;
				file write myfile _tab(3) "stroke: steelblue;" _n
								  _tab(3) "stroke-width: 1;" _n
								  _tab(3) "fill: none;" _n;
			file write myfile _tab(2) "}" _n;
			file write myfile _tab(2) ".axis path, .axis line {" _n;
				file write myfile _tab(3) "fill: none;" _n
								  _tab(3) "stroke: grey;" _n
								  _tab(3) "stroke-width: 1;" _n
								  _tab(3) "shape-rendering: crispEdges;" _n;
			file write myfile _tab(2) "	}" _n;
/* legend style needs to changed... at present it really refers to
   the d3noob-style show/hide text */
			file write myfile _tab(2) ".legend {" _n;
				file write myfile _tab(3) "font-size: 16px;" _n
								  _tab(3) "font-weight: bold;" _n
								  _tab(3) "text-anchor: middle;" _n;
			file write myfile _tab(2) "}" _n;

			file write myfile _tab(2) "button { " _n;
				file write myfile _tab(3) "margin: 0 7px 0 0;" _n
								  _tab(3) "background-color: #f5f5f5;" _n
								  _tab(3) "border: 1px solid #dedede;" _n
								  _tab(3) "border-top: 1px solid #eee;" _n
								  _tab(3) "border-left: 1px solid #eee;" _n
								  _tab(3) "font-size: 12px;" _n
								  _tab(3) "line-height: 130%;" _n
								  _tab(3) "text-decoration: none;" _n
								  _tab(3) "font-weight: bold;" _n
								  _tab(3) "color: #565656;" _n
								  _tab(3) "cursor: pointer;" _n;
			file write myfile _tab(2) "}" _n;
			file write myfile _tab(2) ".dot {" _n;
				file write myfile _tab(3) "fill: rgba(255,255,255,0);" _n
								  _tab(3) "stroke: steelblue;" _n;
			file write myfile _tab(2) "}" _n;
			file write myfile _tab(2) ".area {" _n;
				file write myfile _tab(3) "stroke: none;" _n
								  _tab(3) "fill: steelblue;" _n
								  _tab(3) "fill-opacity: .2;" _n;
			file write myfile _tab(2) "}" _n;
/*			file write myfile _tab(2) ".circle {" _n;
				file write myfile _tab(3) "stroke: none;" _n
								  _tab(3) "fill: red;" _n
								  _tab(3) "fill-opacity: .7;" _n;
			file write myfile _tab(2) "} " _n; */
			file write myfile _tab(2) ".cross {" _n;
				file write myfile _tab(3) "stroke: none;" _n
								  _tab(3) "fill: blue;" _n
								  _tab(3) "fill-opacity: .7;" _n;
			file write myfile _tab(2) "}" _n;
			file write myfile _tab(2) ".diamond {" _n;
				file write myfile _tab(3) "stroke: none;" _n
								  _tab(3) "fill: green;" _n
								  _tab(3) "fill-opacity: .7;" _n;
			file write myfile _tab(2) "}" _n;
			file write myfile _tab(2) ".square{" _n;
				file write myfile _tab(3) "stroke: none;" _n
								  _tab(3) "fill: yellow;" _n
								  _tab(3) "fill-opacity: .7;" _n;
			file write myfile _tab(2) "}" _n;
			file write myfile _tab(2) ".triangle-down{" _n;
				file write myfile _tab(3) "stroke: none;" _n
								  _tab(3) "fill: blueviolet;" _n
								  _tab(3) "fill-opacity: .7;" _n;
			file write myfile _tab(2) "}" _n;
			file write myfile _tab(2) ".triangle-up{" _n;
				file write myfile _tab(3) "stroke: none;" _n
								  _tab(3) "fill: darkred;" _n
								  _tab(3) "fill-opacity: .7;" _n;
			file write myfile _tab(2) "}" _n;
			file write myfile _tab(2) ".bubble{" _n;
				file write myfile _tab(3) "fill-opacity: .3;" _n;
			file write myfile _tab(2) "}" _n;
			file write myfile _tab(2) ".bar{" _n;
				file write myfile _tab(3) "stroke: none;" _n
								  _tab(3) "fill: steelblue;" _n;
			file write myfile _tab(2) "}" _n;
			
			file write myfile _tab(2) "div.tooltip {" _n
									_tab(3) "position: absolute;" _n
									_tab(3) "text-align: center;" _n
									_tab(3) "width: 100px;" _n
									_tab(3) "height: 48px;" _n
									_tab(3) "padding: 2px;" _n
									_tab(3) "font: 12px sans-serif;" _n
									_tab(3) "background: lightsteelblue;" _n
									_tab(3) "border: 0px;" _n
									_tab(3) "border-radius: 8px;" _n
									_tab(3) "pointer-events: none;" _n
							_tab(2) "}" _n _n;
							
		file write myfile _tab "</style>" _n _n;
		
	file write myfile "</head>" _n _n;
	
	file write myfile "<body>" _n;
	file write myfile "<script type='text/javascript'>" _n;

		file write myfile _tab "var margin = {top: 30, left: 80, right: 400, bottom: 70}," _n;
			file write myfile _tab(2) "width = 900 - margin.left - margin.right," _n
							  _tab(2) "height = 300 - margin.top - margin.bottom," _n
							  _tab(2) "axisLabelSpace = 50," _n
							  _tab(2) "legendSpace = 100," _n 
							  _tab(2) "x = d3.scale.linear().range([0, width])," _n
							  _tab(2) "y = d3.scale.linear().range([height, 0])," _n
							  _tab(2) "xAxis = d3.svg.axis().scale(x).orient('bottom').ticks(5)," _n
							  _tab(2) "yAxis = d3.svg.axis().scale(y).orient('left').ticks(5);" _n _n;

		file write myfile _tab "var domainPadding = 0.2;" _n _n;
							  
		file write myfile _tab "var makeline = d3.svg.line()" _n
							  _tab(2) ".x(function(d) { return x(d.xvar); })" _n
							  _tab(2) ".y(function(d) { return y(d.yvar); });" _n;
		file write myfile _tab "svg = d3.select('body')" _n
							  _tab(2) ".append('svg')" _n
									_tab(3) ".attr('width', width + margin.left + margin.right)" _n
									_tab(3) ".attr('height', height + margin.top + margin.bottom)" _n
							  _tab(2) ".append('g')" _n
									_tab(3) ".attr('transform'," _n
										_tab(4) "'translate(' + margin.left + ',' + margin.top + ')');" _n _n;
										
// include tooltip if desired
		if `useonhover'==1 {;
		file write myfile _tab "var div = d3.select('body').append('div')" _n
								_tab(2) ".attr('class', 'tooltip')" _n
								_tab(2) ".style('opacity', 0);" _n _n;
		};

/* THE DATA GOES HERE;
    if there is a d3set variable _d3twlab then use those strings */ ;
capture confirm variable _d3twlab;
tempvar twowaylabels;
if !_rc {;
	gen `twowaylabels' = _d3twlab;
	qui count if _d3twlab!="";
	local nd3twlabs=r(N);
// if there's not enough entries in _d3twlab then complete with "Graph n+1", etc.;
	if `ngraphs'>`nd3twlabs' {;
		forvalues i=(`nd3twlabs'+1)/`ngraphs' {;
			qui replace `twowaylabels' = "Graph `i'" in `i';
		};
	};
};
//otherwise, use "Graph 1", "Graph 2", etc.;
else {;
		gen str20 `twowaylabels' = "Graph 1";
		forvalues i=2/`ngraphs' {;
			qui replace `twowaylabels' = "Graph `i'" in `i';
		};
};
// NOW COMPILE LINEDATA;
if `nline'>0 { ;
	file write myfile _tab "var linedata = [" _n;
	forvalues i=1/`nline' { ;
		local current_line=lineorder[1,`i'];
		local current_label= `twowaylabels'[`current_line'];
		local current_color= "`icolor_`current_line''";
		local current_index=`i'-1;
		qui count; 
		// if and in will come in here;
		local ndata=r(N);
		forvalues j=1/`ndata' {;
			if `g_`current_line'_2'[`j']!=. & `g_`current_line'_3'[`j']!=. {;
				local yval=`g_`current_line'_2'[`j'];
				local xval=`g_`current_line'_3'[`j'];
				file write myfile _tab(3) 
						"{'twoway': '`current_label'', 'xvar': `xval', 'yvar': `yval', " _n
					_tab(3) "'col': `current_color', 'index': `current_index', 'width': `ilwidth_`current_line''}," _n;
			};
		};
	};
	file write myfile _tab(3) "];" _n _n;
};

// NOW COMPILE SCATTERDATA;
if `nscatter'>0 { ;
	file write myfile _tab "var scatterdata = [" _n;
	forvalues i=1/`nscatter' { ;
		local current_scatter=scatterorder[1,`i'];
		local current_label= `twowaylabels'[`current_scatter'];
		local current_color= "`icolor_`current_scatter''";
		local current_index=`i'-1;
		qui count; 
		// if and in will come in here;
		local ndata=r(N);
		forvalues j=1/`ndata' {;
			if `g_`current_scatter'_2'[`j']!=. & `g_`current_scatter'_3'[`j']!=. {;
				local yval=`g_`current_scatter'_2'[`j'];
				local xval=`g_`current_scatter'_3'[`j'];
				file write myfile _tab(3) 
					"{'twoway': '`current_label'', 'xvar': `xval', 'yvar': `yval', " _n
				_tab(3) "'col': `current_color', 'index': `current_index'" ;
	if `useonhover'==1 {;
				local onhovertext = _d3onhover[`j'];
				file write myfile ", " _n
								  _tab(3) "'mo': '`onhovertext''" ;
	};
				file write myfile "}," _n;
			};
		};
	};
	file write myfile _tab(3) "];" _n _n;
};

// END OF THE DATA

		file write myfile _tab "var lineminx = d3.min(linedata, function(d) { return d.xvar; });" _n
						  _tab "var linemaxx = d3.max(linedata, function(d) { return d.xvar; });" _n
						  _tab "var lineminy = d3.min(linedata, function(d) { return d.yvar; });" _n
						  _tab "var linemaxy = d3.max(linedata, function(d) { return d.yvar; });" _n
						  _tab "var scatterminx = d3.min(scatterdata, function(d) { return d.xvar; });" _n
						  _tab "var scattermaxx = d3.max(scatterdata, function(d) { return d.xvar; });" _n
						  _tab "var scatterminy = d3.min(scatterdata, function(d) { return d.yvar; });" _n
						  _tab "var scattermaxy = d3.max(scatterdata, function(d) { return d.yvar; });" _n
						  _tab "var allminx = Math.min(lineminx,scatterminx) - domainPadding * (Math.max(linemaxx,scattermaxx)-Math.min(lineminx,scatterminx));" _n
						  _tab "var allmaxx = Math.max(linemaxx,scattermaxx) + domainPadding * (Math.max(linemaxx,scattermaxx)-Math.min(lineminx,scatterminx));" _n
						  _tab "var allminy = Math.min(lineminy,scatterminy) - domainPadding * (Math.max(linemaxy,scattermaxy)-Math.min(lineminy,scatterminy));" _n
						  _tab "var allmaxy = Math.max(linemaxy,scattermaxy) + domainPadding * (Math.max(linemaxy,scattermaxy)-Math.min(lineminy,scatterminy));" _n _n
						  
						  _tab "x.domain([allminx,allmaxx]);" _n
						  _tab "y.domain([allminy,allmaxy]);" _n _n;

		file write myfile _tab "var linedataNest = d3.nest()" _n
								_tab(2) ".key(function(d) {return d.twoway;})"_n
								_tab(2) ".entries(linedata);" _n _n;
								
		file write myfile _tab "var linelegendSpace = width/linedataNest.length;" _n _n;
		
		file write myfile _tab "linedataNest.forEach(function(d,i) { " _n
							  _tab(2) "svg.append('path')" _n
							  _tab(2) ".attr('class', 'line')" _n
							  _tab(2) ".style('stroke', function() {" _n
									_tab(3) "return linedataNest[i].values[i].col; })" _n
							  _tab(2) ".style('stroke-width', function() {" _n
									_tab(3) "return linedataNest[i].values[i].width; })" _n
							  _tab(2) ".attr('id', 'line'+i)" _n
							  _tab(2) ".attr('d', makeline(d.values));" _n _n;

/* this creates the show/hide text. It needs to be expanded into a legend
   and a series of buttons */							  
		file write myfile _tab "svg.append('text')" _n
							  _tab(2) ".attr('x', width+(legendSpace/2)+i*legendSpace)" _n
							  _tab(2) ".attr('y', legendSpace/2)" _n
							  _tab(2) ".attr('class', 'legend')" _n
							  _tab(2) ".style('fill', function() {" _n
									_tab(3) "return linedataNest[i].values[i].col; })" _n
							  _tab(2) ".on('click', function(){" _n
									_tab(3) "var active = d.active ? false : true," _n
											_tab(4) "newOpacity = active ? 0 : 1;" _n
									_tab(3) "d3.select('#line'+i)" _n
											_tab(4) ".transition().duration(`transition')" _n
											_tab(4) ".style('opacity', newOpacity);" _n
									_tab(3) "d.active = active;" _n
							  _tab(2) "})" _n
							  _tab(2) ".text(d.key);" _n
						  _tab "});" _n _n;
							  
		file write myfile _tab "svg.selectAll('dot')" _n	
							  _tab(2) ".data(scatterdata)" _n
							  _tab(2) ".enter().append('circle')" _n
									_tab(3) ".attr('r', 3.5)" _n
									_tab(3) ".attr('id', function(d,i) {" _n
										_tab(4) "return 'scatter'+d.index;})" _n
									_tab(3) ".style('stroke', function(d,i) {" _n
										_tab(4) "return d.color = d.col; })" _n
									_tab(3) ".style('fill','rgba(255,255,255,0)')" _n
									_tab(3) ".attr('cx', function(d) { return x(d.xvar); })" _n
									_tab(3) ".attr('cy', function(d) { return y(d.yvar); })" _n; 
		if `useonhover'==1 {;
			file write myfile _tab(3) ".on('mouseover', function(d){" _n
									_tab(4) "div.transition()" _n
										_tab(5) ".duration(200)" _n
										_tab(5) ".style('opacity',.9);" _n
									_tab(4) "div.html(d.mo)" _n
										_tab(5) ".style('left',(d3.event.pageX) + 'px')" _n
										_tab(5) ".style('top',(d3.event.pageY - 28) + 'px');" _n
							  _tab(3) "})" _n
							  _tab(3) ".on('mouseout', function(d){" _n
									_tab(4) "div.transition()" _n
										_tab(5) ".duration(500)" _n
										_tab(5) ".style('opacity', 0);" _n
							  _tab(3) "})" _n;
		};
			file write myfile _tab(3) ";" _n;
									
		file write myfile _tab "var scatterdataNest = d3.nest()" _n
							  _tab(2) ".key(function(d) {return d.twoway;})" _n
							  _tab(2) ".entries(scatterdata);" _n _n;
							  
		file write myfile _tab "scatterdataNest.forEach(function(d,i) {" _n
							  _tab(2) "svg.append('text')" _n
									_tab(3) ".attr('x', width+(legendSpace/2)+i*legendSpace)" _n
									_tab(3) ".attr('y', legendSpace)" _n
									_tab(3) ".attr('class', 'legend')" _n
									_tab(3) ".style('fill', function() {" _n
										_tab(4) "return scatterdataNest[i].values[0].col; })" _n
									_tab(3) ".on('click', function(){" _n
										_tab(4) "var active = d.active ? false : true," _n
											_tab(5) "newOpacity = active ? 0 : 1;" _n
										_tab(4) "d3.selectAll('#scatter'+i)" _n
											_tab(5) ".transition().duration(`transition')" _n
											_tab(5) ".style('opacity', newOpacity);" _n
										_tab(4) "d.active = active;" _n
									_tab(3) "})" _n
							  _tab(2) ".text(d.key);" _n
						  _tab "});" _n _n;

		file write myfile _tab "svg.append('g')" _n
								_tab(2) ".attr('class', 'x axis')" _n
								_tab(2) ".attr('transform', 'translate(0,' + height + ')')" _n
								_tab(2) ".call(xAxis);" _n _n;
								
		file write myfile _tab "svg.append('text')" _n
								_tab(2) ".attr('transform','translate('+(width/2)+','+(height+axisLabelSpace)+')')" _n
								_tab(2) ".style('text-anchor','middle')" _n
								_tab(2) ".text('`ixtitle'');" _n _n;
								
		file write myfile _tab "svg.append('g')" _n
								_tab(2) ".attr('class', 'y axis')" _n
								_tab(2) ".call(yAxis);" _n _n;

		file write myfile _tab "svg.append('text')" _n
								_tab(2) ".attr('transform','rotate(-90)')" _n
								_tab(2) ".attr('x',0-(height/2))" _n
								_tab(2) ".attr('y',0-axisLabelSpace)" _n
								_tab(2) ".attr('dy','1em')" _n
								_tab(2) ".style('text-anchor','middle')" _n
								_tab(2) ".text('`iytitle'');" _n _n;

file write myfile "</script>" _n;
file write myfile "</body>" _n;

#delimit cr
dis as result "`filename' successfully written"
}
file close myfile


end
