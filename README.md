Stata2D3
================

*The master branch of this repo is work in progress over summer 2019. We presented it at Stata's London conference in September. Before [the devil spits on your brambles](https://www.nationalgeographic.com/people-and-culture/food/the-plate/2015/09/28/michaelmas-the-day-the-devil-spit-on-your-blackberries/), we will have the various parts all up and running and talking to each other. Until then, you are advised not to rely on it to work in any way whatsoever!*

## Overview

This is a collection of Stata commands that allow you to export your Stata graphics into an interactive webpage. Essentially, it saves your graph as SVG format, annotates that, wraps it in an HTML file with link to the [D3](https://d3js.org) JavaScript library, and if you wish, it adds some D3 code to give you a little interactivity. It requires Stata versions 14+ (but see below).
For example:
```
sysuse auto, clear
d3, clickright(make) hovertip(hoverfacts) mgroups(foreign) ///
    htmlfile("d3_html_test.html") locald3 replace: ///
    scatter price mpg, scheme(s1mono)
```
When you click on a marker, the content of the "make" variable will appear to the right of the graph. There will also be buttons underneath for "Foreign", "Domestic" (the two levels of the "foreign" variable) and "all data", which highlight markers in that group. You can view the sort of file this produces in the file d3_html_test.html in this repo.

An equivalent example, using individual commands rather than -d3-:
```
sysuse auto, clear
gen hoverfacts = strofreal(mpg) + " MPG, $" + strofreal(price)
scatter price mpg, scheme(s1mono)
graph export "auto.svg", replace
d3_tag "auto.svg", mgroups(foreign) out("autotagged.svg") replace
d3_html "autotagged.svg", htmlfile("d3_html_test.html") svgv(16) locald3 ///
  clickright(make) hovertip(hoverfacts) groupbuttons(foreign) replace

```
In -d3_tag-, we define the group variable for the markers using mgroups() -- this is because it has to be written into the SVG code.
In -d3_html-, we have to tell it the version of Stata that wrote the SVG file (this is extracted from the SVG code by -d3-, and it may not be the same as the running instance of Stata) in the svgversion() option, the variable to be displayed to the right of the graph when markers are clicked (clickright() option), and the variable that defines the groups for markers or paths using groupbuttons().

You might wish to generate your own SVG file, then tag it manually, then run **d3_html** on it. See the section **What does d3_html look for?** below.

At present, d3 does not pass all options forward to the subsidiary commands. Only circles are acted on for interactivity. Take a look at the issues in this repo if you want to see what's coming up or under debate.

## Commands

### d3
**d3** is the wrapper for everything else. It parses and hands out instructions. **d3** is a prefix, so there are options before the colon specific to interaction in the browser, and after the colon you supply a standard Stata graph-making command.


### d3_make

**d3_make** creates the SVG file requested

### d3_tag

**d3_tag** takes an SVG graph file exported by Stata, scans it for objects ike the plot region, axes, axis titles, gridlines, circles and lines inside the plotregion, and so on. Once it has found those, it adds *ids* and *classes* (which we collectively call "tags" here, much to the horror of full-stack rockstar web devz), which help D3 keep track of what's going on, and what it can change or interact with inside the SVG.
It can only work with SVG exported by Stata because those files follow a clearly specified structure, and **d3_tag** uses that structure to find its way around; you can't feed files from other software into it, nor can you amend your Stata SVG in Inkscape or Illustrator, and then plug it into **d3_tag**.

* **d3_tag** *filename*, Outputfile(*filename*) MGroups(*varname numeric*) LGroups(*varname numeric*) Replace
* The filename before the comma is the input SVG file. We do not check that it is a valid SVG file but it must exist. You must type it in quotes.
* Outputfile is self-explanatory, this is where the tagged file gets saved, unless you choose Replace. It will be another SVG file, identical when viewed in the browser or vector graphics editor, but with tags added.
* MGroups is a variable that contains integers telling svgtag which group each marker belongs to. These will be added as classes. The variable can have missing values, which will create a class "markergroup.", which will have no effect. If you need more values than there are obs in the dataset, you can use a different data frame in Stata v16. We might add a matrix option for v14-15 later.
* LGroups does the same for lines inside the plotregion. Note that this actually acts on SVG objects called paths, which are only output from Stata v16 onward.
* Replace has the usual function.

### d3_html

**d3_html** takes a tagged SVG file in line with the specifications of **d3_tag**, and wraps it with appropriate HTML, CSS and JavaScript. You could use this if there are some quirks in your graph that mean it would be easier to tag it manually (or adjust it after running **d3_tag**). You can find the complete list of features that **d3_html** will look for in an SVG file below.




## Limitations
Stata2D3 aims to get as close as possible to one monolithic program to make interactive content from any Stata graph. You might well argue that this is foolish, and we don't entirely disagree. It is intended as a stepping stone, to help people make something quickly that they can then edit, or give to web developers, or to help them learn about SVG, HTML and JavaScript. It is never going to do everything for you, but it can get you started. For example, the buttons for highlighting groups of data are the most basic of HTML buttons; they look like it's still the 1990s. It's up to you to style them. You can also hack the SVG to get the command **d3_html** to do other things for you that would be too complex for **d3**. Once you learn some SVG+HTML+CSS+JS from this, you won't look back, and maybe that's the secret purpose of Stata2D3.
> It's educational
— *"U-Mass". Pixies, The. 1991*

Clearly, there are a gazillion ways you can make a Stata graph, so there are limitations on what you can feed into it. There are also a frazillion ways you can use interactivity, so we just supply the most common ones and leave it to you to tweak the resulting combination of SVG, HTML and JavaScript.

Because we use Stata's ability to export a graph to an SVG file, which only appeared from version 14 onward, this version of Stata2D3 simply will not work with older versions. See **Older versions of Stata** below for alternatives.

If you are using version 14 or 15, you can add interactivity for circles but not lines. This is simply because line charts were made up of lots of very short straight lines rather than SVG paths in those versions. We can't second-guess which of these lines you intended to make up one path, but you might be able to use a tool like Inkscape to edit your lines into one path (or indeed edit them manually!) and then run **d3_tag**, manually tag the paths (because they will not be) and then run **d3_html**.

The group variable must be numeric. We intend this to be an integer with value labels. The integer values will be used internally in the SVG tagging and the JavaScript (hence, no decimal places, please!) and the label text will be used in buttons.

### Limitations on the Stata graphs
* There are two approaches to adding data for interactivity (by this, we mean data that are not already encoded in the image as x-location or y-location). In either case, we begin by inviting the user to supply a variable name or row/column matrix (see below), which contains the data they want displayed, for example in a tooltip.
    1. Require the new data to be in the same order as the objects in the SVG (this is observation order, within each component of a twoway graph, though this does not apply at all to graphs of stats like boxplots). This is easy to code but has limitations and puts the onus on the user.
    2. Allow the new data to be in any order, and to include x-y locations (or maybe, for more advanced users, an id, to match that added by **d3_tag**) of the objects to which they relate. This requires us to calculate the data-to-pixel scale so we can find objects within a certain tolerance of the specified location and attach the data. This is more flexible for users, but I'm not sure how many would want to use additional data that were not in a variable. Also, it's not foolproof as there could be more than one object at a location.
    * We are working with option (i) and might expand to option (ii), depending on the experience of early adopters.
    * note also that string data (which will usually be the case) has to be in a variable, so if data are plotted multiple times, the variable will need to be longer than _N; in v16+ it can be in a different data frame, but in v14-15 it would have to be created in Mata, and we need to work out how this would then be specified in -d3-
* We identify graphregion and plotregion (and from this, axes, ticks, gridlines and data-representing paths) on the basis of the first group of rect objects in the SVG. In Stata 14-16, these appear at the beginning of the SVG file (long may this continue...) but there are between two and six depending on version, scheme, presence of shading, and presence of plotregion box. We take x, y, width and height from the first to be the graphregion (which is often the same as the viewBox), while the plotregion is identified by finding the last rect at the beginning of the file (this is why we read in nextline), then:
    * for v14:
		    * simply use x, y, x+width, y+height
		* for v15-16:
		    * half the value of stroke-width (if there is stroke-width) is subtracted from x to get the left edge
		    * this left edge location is added to the width to get the right edge
		    * and analogously for top and bottom.
    * On this basis, plotregions must be smaller than graphregions, and if you add bespoke borders and shading to them, you could have unexpected results. If you must have such touches, run **d3_tag**, then amend the tagged SVG, then run **d3_html**.
* If we implement option (ii) above, all graphs must have x and y axes, with ticks and labels, even if they are invisible (this is because we will read data values from xlabel and ylabel to allow creation of d3 scales e.g. for tooltip values as the mouse moves along a line chart; at present we do not have this functionality and the axis requirement is not enforced)
* Axes may not be inside the plotregion (a horizontal axis at zero in the middle of the graph, for example). You can add them later but any line inside the plotregion might be misinterpreted as data
* Surely you wouldn't make a graph with two y-axes. Would you? Well, don't do it here. y-axis must be on the left edge of the plotregion and x axis on the bottom edge. (this is because of the potential use of option (ii) above) We make no guarantee of how z-axes and other wacky stuff will affect the output.
* At present, we only deal with circular marker symbols. You can output other shapes and they will be carried through, but we can't apply interactivity to them (yet).
* We don't apply interactivity to lines from Stata versions 14 or 15, as explained above.
* If we adopted option (ii), we'd have to work with linear scales only (because we read the axis labels to get a data-to-pixel conversion); this could be extended to log scales in future
* our approach to these limitations is *not* to check them but to warn the user here and in the help files that things may well go awry if they do not comply

### Limitations on the D3 interactivity
* We provide these so far:
    * display text from a string variable alongside or under the graph on hover/click
    * buttons to change opacity to highlight one class of markers
* We have these on our radar:
    * tooltips
    * buttons to change opacity to highlight one class of lines (paths, from Stata 16 only)
    * allow any SVG attribute or styling to be amended on click/hover
    * filter the displayed graphic by other variables: range selectors for numeric variables and tickboxes for labelled numeric, or string, variables
    * More marker symbols
    * working with areas, polygons, rcap, rspike...
    * replacing Stata markersymbols and lines with something else (*cf* hexagon plot in the stata-svg repo)
    * and we'd like to consider scrollytelling (more on that later)
* We don't intend to include interaction commands specific to touchscreens.
* These are interesting but perhaps too hard to provide in a generic function:
    * a collection of graphs (via -graph combine- perhaps) that filter each other by rectangle selection in the manner of crossfilter.js
    * see also the note below on D3 axes and scales

* At present, the SVG is written into the HTML, so you can't use D3 functionality that relies on axes, scales and so forth. This rules out zooming. Anything that just interacts with a DOM object (and, potentially, changes that one object or others of its class) will be fine. We might consider a translator to D3 axes in due course, but right now, we're not convinced of its merits in the scenario where you want a Stata graph reproduced. Feel free to try to convince us otherwise.


## Older versions of Stata (13 and older)

There is an older (and very limited) version of Stata2D3 which you can find here in the **pre-svg** branch. That will work with versions of Stata before 14, when SVG output appeared. If you have 14 and up, this **master** branch version is highly recommended: it has vastly more functionality because it is not attempting to re-draw the graph from scratch.


## What does d3_html look for?
* It will ignore Stata version as declared at the top of the SVG file, allowing you to manually edit your SVGs (especially for line-to-path conversion). Instead you should supply the version in the svgversion() option. Remember that this is the version of Stata used to create the SVG, not necessarily the version you are running to execute **d3_html**.
* Circles that you want to have hover/click text display should have the "markercircle" class. Remember that they will be matched with the variable you provide for clickright(), hoverbelow() and the like in the order that they occur in the SVG file, and the order of observations in the data frame. It is up to you to get this right -- we can't check it for you!
* You could experiment with manually adding the "markercircle" class to objects that are not circles in a scatterplot (or scatter plot, if you are Nick Cox). This might allow you to get interactivity on other objects, or <g> groups of objects, but we make no guarantee of how it will work -- do so at your own risk.
* Circles that will be highlighted as members of a category should have class like "markercircle1" if the mgroups() variable in **d3** (which is handed to the groupbuttons() option in **d3_html**) has a value 1. The value label associated with 1 will appear in the relevant button. The same applies to SVG paths created with Stata v16, but in that case you use the lgroups() option and it is also handed to groupbuttons(). See issue #5.

### Thank you:
* Brennan Kahan
* Billy Buchanan

### If you want to learn about JavaScript, D3, etc:
* [Scott Murray](https://alignedleft.com/)'s book *Interactive Data Visualization for the Web* is probably the best D3 intro out there.
* Marijn Haverbeke's book [*Eloquent JavaScript*](http://eloquentjavascript.net/) is an excellent introduction to the language.
* and to learn HTML and CSS, you can't go wrong at [w3schools.com](https://www.w3schools.com/)
