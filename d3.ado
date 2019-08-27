*! version 0.1, 12aug2019 | Rob Grant & Tim Morris

program define d3
    version 15

    set prefix d3 // We might end up not needing this

    mata: _parse_colon("hascolon", "rhscmd")
//noisily di as text `"`0'"'
    * Run the twoway part and output svg that can be used by d3_make
    if !regexm("`rhscmd'",",") local rhscmd `rhscmd' ,
    `rhscmd'

    * Send the d3 stuff to d3_make
    d3_make `0'

end



program define d3_make
    version 15
    syntax [ anything ] /// D3 options below tbc
        , SAVing(string) ///
        [ ///
        savesvg(string) ///
        CLICKBelow(varname) /// show content of varname below on click
        CLICKRight(varname) /// show content of varname to the right on click
        CLICKPopup(varname) /// show content of varname in a popup (tooltip) on click
        HOVERBelow(varname) /// show content of varname below on hover
        HOVERRight(varname) /// show content of varname to the right on hover
        HOVERPopup(varname) /// show content of varname in a popup (tooltip) on hover
        CLICKHighlight(varname numeric) /// highlight all markers/paths in the same group, defined by varname and shown using its labels
        HOVERHighlight(varname numeric) /// highlight all markers/paths in the same group, defined by varname and shown using its labels
        D3LIBrary(string) ///
        local(string) ///
        /// highlighting variable is passed to Groups in -svgtag-
        ]

    * Saving of .html file
    tokenize `"`saving'"', parse(",")
    if "`3'" != "replace" capture confirm file `"`1'"'
    if "`3'" != "replace" & _rc != 601 {
        display as error "File `"`1'"' already exists." // Please specify saving(`"`1'"', replace) to replace it"
        exit 602
    }
    else {
        local savename `1' // `savename' will be the .html file to save
    }

    * Saving of .svg file; either for creation of .html or to have standalone
    if "`savesvg'" == "" {
        tempfile svgfile
        quietly graph export `"`svgfile'"', as(svg)
    }
    else {
        tokenize `"`savesvg'"', parse(",")
        if "`3'" == "replace" local repsvg replace
        if regexm(`"`savesvg'"', ".svg") quietly graph export `1', as(svg) `repsvg'
        else if !regexm(`"`savesvg'"', ".svg") quietly graph export `1'.svg, as(svg) `repsvg' // This line isn't adding .svg extension (27aug2019)
        local svgfile `"`1'"'
    }

    * If a local d3 library is not linked to, default to v3 at the mothership: http://d3js.org/d3.v3.min.js
    if `"`d3library'"' == "" {
        local d3library http://d3js.org/d3.v3.min.js
        display as text "Note: using d3 library at " as result "`d3library'"
    }
    else if `"`d3library'"' != "" !regexm(`"`d3library'"',"https://") confirm file `"`d3library'"' // confirm existence of local file

    * Now time to call d3 commands
    
    
    * Following d3 stuff, ensure any temporary .svg files created get removed
    if "`savesvg'" == "" capture erase `"`svgfile'"'
end


exit
* * * *


History of d3.ado
0.2  27aug2019 | Better structure and additional options following comments; debugging
0.1  12aug2019 | First attempt at syntax for d3 command
