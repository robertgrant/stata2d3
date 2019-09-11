*! version 0.3.1, 11sep2019 | Rob Grant & Tim Morris
* r(100); "Rob" is deprecated.

program define d3
	local svgversion = c(version)
    version 14

    set prefix d3 // We might end up not needing this

    mata: _parse_colon("hascolon", "rhscmd")
    * Run the graph part ready for d3_make to export
    if !regexm("`rhscmd'",",") local rhscmd `rhscmd' ,
    `rhscmd'

    * Send everything else to d3_make and get parsed options back
    d3_make `0'
	local svgfile = r(svgfile)
	local replaceoption = r(replaceoption)
	local taggedsvgfile = r(taggedsvgfileoption)
	local htmlfile = r(htmlfileoption)
	// get varnames, some of which may be absent
	local clickbelow = r(clickbelowoption)
	local clickright = r(clickrightoption)
	local clicktip = r(clicktipoption)
	local hoverbelow = r(hoverbelowoption)
	local hoverright = r(hoverrightoption)
	local hovertip = r(hovertipoption)
	local mgroups = r(mgroupsoption)
	local lgroups = r(lgroupsoption)
	// turn these into options (or blank)
	foreach opt in clickbelow clickright clicktip hoverbelow hoverright hovertip mgroups lgroups {
		if "``opt''"=="" | "``opt''"=="." {
			local `opt' = ""
		}
		else {
			local `opt' = "`opt'(``opt'')"
		}
	}
	
	// Call d3_tag
	d3_tag `"${svgfile}"', outputfile(`"${taggedsvgfile}"') `mgroups' `lgroups' `replaceoption'
	
	// Call d3_html
	d3_html `"${taggedsvgfile}"', htmlfile(`"`htmlfile'"')  ///
	                             `clickbelow' `clickright' `clicktip' `hoverbelow' `hoverright' `hovertip' ///
								 `mgroups' `locald3' svgversion(`svgversion') `replaceoption'

end



program define d3_make, rclass
    version 14
    syntax [ anything ] /// in fact, we expect nothing here
        , HTMLfile(string) /// where the final HTML file gets saved; must be given
        [ ///
		SVGfile(string) /// where Stata saves the exported SVG (untagged) file
		TAGgedsvgfile(string) /// where d3_tag saves the tagged SVG file
        KEEPfiles /// if keepfiles, then svgfile and taggedsvgfile are NOT deleted
        CLICKBelow(varname) /// show content of varname below on click
        CLICKRight(varname) /// show content of varname to the right on click
        CLICKTip(varname) /// show content of varname in a popup (tooltip) on click - not used at present
        HOVERBelow(varname) /// show content of varname below on hover
        HOVERRight(varname) /// show content of varname to the right on hover
        HOVERTip(varname) /// show content of varname in a popup (tooltip) on hover
        MGroups(varname numeric) /// buttons to highlight all markers in the same group, defined by varname and shown using its labels
        LGroups(varname numeric) /// highlight all paths in the same group, defined by varname and shown using its labels - not used at present
        REPlace /// this applies to svgfile, taggedsvgfile, and htmlfile. We could split them up...
        LOCald3 /// point to d3.v3.min.js; otherwsie, point to https://d3js.org/d3.v3.min.js
        ]

    // Check htmlfile
    if "`replace'" != "replace" capture confirm file `"`htmlfile'"'
    if "`replace'" != "replace" & _rc != 601 {
        display as error `"File `"`htmlfile'"' already exists. Use the replace option or a different name."' 
        exit 602
    }

    // keepfiles requires names for svgfile and taggedsvgfile; otherwise, they get tempfiles
    if "`keepfiles'" == "keepfiles" {
		if `"`svgfile'"'!="" {
			capture confirm file `"`svgfile'"'
			if _rc != 601 & "`replace'"!="replace" {
				display as error `"File `"`svgfile'"' already exists. Use the replace option or a different name."' 
				exit 602
			}
			else {
				global svgfile `"`svgfile'"'
			}
		}
		else {
			display as error "svgfile must be specified if you use the keepfiles option."
			exit 198
		}
		if `"`taggedsvgfile'"'!="" {
			capture confirm file `"`taggedsvgfile'"'
			if _rc != 601 & "`replace'"!="replace" {
				display as error `"File `"`taggedsvgfile'"' already exists. Use the replace option or a different name."' 
				exit 602
			}
			else {
				global svgfile `"`taggedsvgfile'"'
			}
		}
		else {
			display as error "taggedsvgfile must be specified if you use the keepfiles option."
			exit 198
		}
    }
	else {
		tempfile svgfile
		global svgfile `"`svgfile'"'
		tempfile taggedsvgfile
		global taggedsvgfile `"`taggedsvgfile'"'
	}
	/* Note that, if keepfiles is not specified, it doesn't matter what is in svgfile or taggedsvgfile.
	   The interim files will go to tempfiles and be deleted when the Stata session closes. */
	
	// save the graph as the svgfile
	quietly graph export `svgfile', as(svg) `replace'

	// local or muthaship d3 library?
    if `"`locald3'"' == "" {
        local d3libloc "http://d3js.org/d3.v3.min.js"
    }
    else {
        local d3libloc "d3.v3.min.js"
	}
	
	return local svgfile = `"`svgfile'"'
	return local replaceoption = "`replace'"
	return local taggedsvgfileoption = `"`taggedsvgfile'"'
	return local htmlfileoption = `"`htmlfile'"'
	return local clickbelowoption = "`clickbelow'"
	return local clickrightoption = "`clickright'"
	return local clicktipoption = "`clicktip'"
	return local hoverbelowoption = "`hoverbelow'"
	return local hoverrightoption = "`hoverright'"
	return local hovertipoption = "`hovertip'"
	return local mgroupsoption = "`mgroups'"
	return local lgroupsoption = "`lgroups'"
	
end


exit
* * * *


History of d3.ado
0.3  09sep2019 | Options matched to d3_tag and d3_html
0.2  27aug2019 | Better structure and additional options following comments; debugging
0.1  12aug2019 | First attempt at syntax for d3 command
