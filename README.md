Stata2D3
================

*The master branch of this repo is work in progress over summer 2019. We will launch at Stata's London conference in September. Until then, you are advised not to rely on it to work in any way whatsoever!*

## Overview

This is a collection of Stata commands that allow you to export your Stata graphics into an interactive webpage. Essentially, it saves your graph as SVG format, annotates that, wraps it in an HTML file with link to the [D3](https://d3js.org) JavaScript library, and if you wish, it adds some D3 code to give you a little interactivity. It requires Stata versions 14+ (but see below).
For example (aspirations for the StataConf version, not yet possible):
* sysuse auto, clear
* d3, clickright(make) mgroups(foreign) htmlfile("mypage.html"): scatter price mpg, scheme(s1mono)
* *When you click on a marker, the content of the "make" variable will appear to the right of the graph.*
* *There will also be buttons underneath for "Foreign", "Domestic" (the two levels of the "foreign" variable) and "all data", which highlight markers in that group.*

Another example (what is currently possible):
* sysuse auto, clear
* scatter price mpg, scheme(s1mono)
* graph export "mygraph.svg", replace
* d3_tag "auto.svg", mgroups(foreign) out("autotagged.svg") replace
* d3_html "autotagged.svg", htmlfile("d3_html_test.html") svgv(16) clickright(make) groupbuttons(foreign)
* * and you can view the resulting file here in this repo*

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
Stata2D3 aims to get as close as possible to one monolithic program to make interactive content from any Stata graph. You might well argue that this is foolish, and we don't entirely disagree. It is intended as a stepping stone, to help people make something quickly that they can then edit, or give to web developers, or to help them learn about SVG, HTML and JavaScript. It is never going to do everything for you, but it can get you started.
> The longest of journeys begins with a single grep
— *Stephen Senn's Sayings Of Confuseus (apocrypha)*

Clearly, there are a gazillion ways you can make a Stata graph, so there are limitations on what you can feed into it. There are also a frazillion ways you can use interactivity, so we just supply the most common ones and leave it to you to tweak the resulting combination of SVG, HTML and JavaScript.

Because we use Stata's ability to export a graph to an SVG file, which only appeared from version 14 onward, this version of Stata2D3 simply will not work with older versions. See **Older versions of Stata** below for alternatives.

If you are using version 14 or 15, you can add interactivity for circles but not lines. This is simply because line charts were made up of lots of very short straight lines rather than SVG paths in those versions. We can't second-guess which of these lines you intended to make up one path, but you might be able to use a tool like Inkscape to edit your lines into one path (or indeed edit them manually!) and then run **d3_tag**, manually tag the paths (because they will not be) and then run **d3_html**.

The group variable must be numeric. We intend this to be an integer with value labels. The integer values will be used internally in the SVG tagging and the JavaScript (hence, no decimal places, please!) and the label text will be used in buttons.

### Limitations on the Stata graphs
* There are two approaches to adding data for interactivity (by this, we mean data that are not already encoded in the image as x-location or y-location). In either case, we begin by inviting the user to supply a variable name or row/column matrix (see below), which contains the data they want displayed, for example in a tooltip.
    1. Require the new data to be in the same order as the objects in the SVG (this is observation order, within each component of a twoway graph, though this does not apply at all to graphs of stats like boxplots). This is easy to code but has limitations and puts the onus on the user.
    2. Allow the new data to be in any order, and to include x-y locations (or maybe, for more advanced users, an id, to match that added by **d3_tag**) of the objects to which they relate. This requires us to calculate the data-to-pixel scale so we can find objects within a certain tolerance of the specified location and attach the data. This is more flexible for users, but I'm not sure how many would want to use additional data that were not in a variable. Also, it's not foolproof as there could be more than one object at a location.
    * We are working with option 1 and might expand to option 2, depending on the experience of early adopters.
    * note also that string data (which will usually be the case) has to be in a variable, so if data are plotted multiple times, the variable will need to be longer than _N; in v16+ it can be in a different data frame, but in v14-15 it would have to be created in Mata, and we need to work out how this would then be specified in **d3**
* We identify graphregion and plotregion (and from this, axes, ticks, gridlines and data-representing paths) on the basis of the first group of rect objects in the SVG. In Stata 14-16, these appear at the beginning of the SVG file (long may this continue...) but there are between two and six depending on version, scheme, presence of shading, and presence of plotregion box. We take x, y, width and height from the first to be the graphregion (which is often the same as the viewBox), while the plotregion is identified by finding the last rect at the beginning of the file (this is why we read in nextline), then:
    * for v14:
		    * simply use x, y, x+width, y+height
		* for v15-16:
		    * half the value of stroke-width (if there is stroke-width) is subtracted from x to get the left edge
		    * this left edge location is added to the width to get the right edge
		    * and analogously for top and bottom.
    * On this basis, plotregions must be smaller than graphregions, and if you add bespoke borders and shading to them, you could have unexpected results. If you must have such touches, run **svgtag**, then amend the tagged SVG, then run **d3pretagged**.
* If we implement option (ii) above, all graphs must have x and y axes, with ticks and labels, even if they are invisible (this is because we will read data values from xlabel and ylabel to allow creation of d3 scales e.g. for tooltip values as the mouse moves along a line chart; at present we do not have this functionality and the axis requirement is not enforced)
* Axes may not be inside the plotregion (a horizontal axis at zero in the middle of the graph, for example). You can add them later but any line inside the plotregion might be misinterpreted as data
* Surely you wouldn't make a graph with two y-axes. Would you? Well, don't do it here. y-axis must be on the left edge of the plotregion and x axis on the bottom edge. (this is because of the potential use of option (ii) above) We make no guarantee of how z-axes and other wacky stuff will affect the output.
* At present, we only deal with circular marker symbols. You can output other shapes and they will be carried through, but we can't apply interactivity to them (yet).
* We don't apply interactivity to lines from Stata versions 14 or 15, as explained above.
* If we adopted option (ii), we'd have to work with linear scales only (because we read the axis labels to get a data-to-pixel conversion); this could be extended to log scales in future
* our approach to these limitations is *not* to check them but to warn the user that things may well go awry if they do not comply

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
    * a collection of graphs (via **graph** **combine** perhaps) that filter each other by rectangle selection in the manner of crossfilter.js
    * see also the note below on D3 axes and scales

* At present, the SVG is written into the HTML, so you can't use D3 functionality that relies on axes, scales and so forth. This rules out zooming. Anything that just interacts with a DOM object (and, potentially, changes that one object or others of its class) will be fine. We might consider a translator to D3 axes in due course, but right now, we're not convinced of its merits in the scenario where you want a Stata graph reproduced. Feel free to try to convince us otherwise.


## Older versions of Stata (13 and older)

There is an older (and very limited) version of Stata2D3 which you can find here in the **pre-svg** branch. That will work with versions of Stata before 14, when SVG output appeared. If you have 14 and up, this **master** branch version is highly recommended: it has vastly more functionality because it is not attempting to re-draw the graph from scratch.


## What does d3_html look for?
* It will ignore Stata version as declared at the top of the SVG file, allowing you to manually edit your SVGs (especially for line-to-path conversion). Instead you should supply the version in the svgversion() option
* Circles that you want to have hover/click text display should have the "markercircle" class. Remember that they will be matched with the variable you provide for clickright(), hoverbelow() and the like in the order that they occur in the SVG file, and the order of observations in the data frame. It is up to you to get this right -- we can't check it for you!
* Circles that will be highlighted as members of a category should have class like "markercircle1" if the mgroups() variable in **d3** (which is handed to the groupbuttons() option in **d3_html**) has a value 1. The value label associated with 1 will appear in the relevant button.

### Thank you:
* Brennan Kahan
* Billy Buchanan
