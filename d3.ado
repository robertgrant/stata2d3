*! version 0.1, 12aug2019 | Rob Grant & Tim Morris

program define d3
    version 15

    set prefix d3 // We might end up not needing this

    mata: _parse_colon("hascolon", "rhscmd")
noisily di as text `"`0'"'
    * Run the twoway part and output svg that can be used by d3_make
    if !regexm("`rhscmd'",",") local rhscmd `rhscmd' ,
    `rhscmd' // 'nodraw' for speed?
// I'd leave it to the user. If they specify nodraw, it'll nodraw for them, but
// otherwise I think it should do what they usually expect to see from a graph command

    * Send the d3 stuff to d3_make
    d3_make `0'

end



program define d3_make
    version 15
    syntax [ anything ] /// D3 options below tbc
        , SAVing(string) ///
        [ ///
        CLICKBelow(varname) /// show content of varname below on click
        CLICKRight(varname) /// show content of varname to the right on click
        CLICKPopup(varname) /// show content of varname in a popup (tooltip) on click
        HOVERBelow(varname) /// show content of varname below on hover
        HOVERRight(varname) /// show content of varname to the right on hover
        HOVERPopup(varname) /// show content of varname in a popup (tooltip) on hover
        CLICKHighlight(varname numeric) /// highlight all markers/paths in the same group, defined by varname and shown using its labels
        HOVERHighlight(varname numeric) /// highlight all markers/paths in the same group, defined by varname and shown using its labels
        /// highlighting variable is passed to Groups in -svgtag-
        ]

    // handle 'saving(name, replace)'
    tokenize "`saving'", parse(",")
    if "`3'" == "" &  regexm("`1'",".svg") capture confirm file `"`1'"'     // #ROB - is it fair to check for existence of .svg file? Should it be .html/other?
/* I thought the saving() option in -d3- tells it where to save the eventual .html file, while -d3_make- makes a new (perhaps tempfile) svg file, and then -svgtag- makes another version of it, so we probably need a savesvg option that gets used to keep or dump those interim files.
   -svgwithjs- makes the html file, so saving() is passed to it.
*/
    if "`3'" == "" & !regexm("`1'",".svg") capture confirm file `"`1'.svg"'
    if "`3'" != "" & _rc != 601 display as error "File `1' already exists." // Specify saving(`"`1'"', replace) to replace it"
    else local savename `1' // `savename' will be file to save

    graph export `savename'.svg, replace //

    * Now time for actual d3 stuff (I think)
end


exit
* * * *



History of d3.ado
0.1  12aug2019 | First attempt at syntax for d3 command
