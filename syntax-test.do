* Test the syntax of d3 command

* Very simple command
sysuse auto
program drop _all
d3, saving(t1, replace) : twoway scatter price mpg


* More complex commands
