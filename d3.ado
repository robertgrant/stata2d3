*! version 0.1, 12aug2019 | Rob Grant & Tim Morris

program define d3
    version 15
    
    set prefix d3 // We might end up not needing this

    mata: _parse_colon("hascolon", "rhscmd")
noisily di as text `"`0'"'
    * Run the twoway part and output svg that can be used by d3_make
    if !regexm("`rhscmd'",",") local rhscmd `rhscmd' ,
    `rhscmd' // 'nodraw' for speed?

    * Send the d3 stuff to d3_make
    d3_make `0'
    
end



program define d3_make
    version 15
    syntax [ anything ] /// D3 options below tbc
        , SAVing(string) ///
        [ ///
        click(varlist) /// pop up when you click on marker
        HOVer(varlist) /// pop up as you hover over marker
        HIGHLight(string) /// fade other markers / lines
        ]

    // handle 'saving(name, replace)'
    tokenize "`saving'", parse(",")
    if "`3'" == "" &  regexm("`1'",".svg") capture confirm file `"`1'"'     // #ROB - is it fair to check for existence of .svg file? Should it be .html/other?
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
