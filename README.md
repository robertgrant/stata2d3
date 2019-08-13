Stata2D3
================

*The master branch of this repo is work in progress over summer 2019. We will launch at Stata's London conference in September. Until then, you are advised not to rely on it to work in any way whatsoever!*

## Overview

This is a collection of Stata commands that allow you to export your Stata graphics into an interactive webpage. Essentially, it saves your graph as SVG format, annotates that, wraps it in an HTML file with link to the [D3](https://d3js.org) JavaScript library, and if you wish, it adds some D3 code to give you a little interactivity. It requires Stata versions 14+ (but see below).
Here's some examples:
* *these are aspirational notes of work in progress and no guarantee of syntax to come*
* sysuse auto, clear
* d3, hover_tooltip(make): scatter price mpg // adds a tooltip on mouse hover which shows the text in the **make** variable


## Commands
**svgtag** takes an SVG graph file exported by Stata, scans it for objects ike the plot region, axes, axis titles, gridlines, circles and lines inside the plotregion, and so on. Once it has found those, it adds *ids* and *classes* (which we collectively call "tags" here, much to the horror of full-stack rockstar web devz), which help D3 keep track of what's going on, and what it can change or interact with inside the SVG.
It can only work with SVG exported by Stata because those files follow a clearly specified structure, and **svgtag** uses that structure to find its way around; you can't feed files from other software into it, nor can you amend your Stata SVG in Inkscape or Illustrator, and then plug it into **svgtag**.

**d3** is a prefix, so there are options before the colon specific to interaction in the browser, and after the colon you supply a standard Stata graph-making command. Whatever is in the active graph window is then exported to a temporary SVG format file. It calls **svgtag** and **svgwithjs** (which we might want to rename).

**d3pretagged** does all the actions of **d3**, starting from the point after **svgtag** has run. You could use this if there are some quirks in your graph that mean it would be easier to tag it manually (or adjust it after running **svgtag**). It calls **svgwithjs** (which we might want to rename). You can find the complete list of features that **d3pretagged** will look for in an SVG file below.

There are some other SVG-manipulating commands at [stata-svg](https://github.com/robertgrant/stata-svg) that you might find useful.



## Limitations
Stata2D3 aims to get as close as possible to one monolithic program to make interactive content from any Stata graph. You might well argue that this is foolish, and we don't entirely disagree. It is intended as a stepping stone, to help people make something quickly that they can then edit, or give to web developers, or to help them learn about SVG, HTML and JavaScript. It is never going to do everything for you, but it can get you started.
> The longest of journeys begins with a single HTML file
— *Stephen Senn (apocryphal)*

Clearly, there are a gazillion ways you can make a Stata graph, so there are limitations on what you can feed into it. There are also a frazillion ways you can use interactivity, so we just supply the most common ones and leave it to you to tweak the resulting combination of SVG, HTML and JavaScript.

Because we use Stata's ability to export a graph to an SVG file, which only appeared from version 14 onward, this version of Stata2D3 simply will not work with older versions. See **Older versions of Stata** below for alternatives.

If you are using version 14 or 15, you can add interactivity for circles but not lines. This is simply because line charts were made up of lots of very short straight lines rather than SVG paths in those versions. We can't second-guess which of these lines you intended to make up one path, but you might be able to use a tool like Inkscape to edit your lines into one path (or indeed edit them manually!) and then run svgtag, manually tag the paths (because they will not be) and d3pretagged.

### Limitations on the Stata graphs
* There are two approaches to adding data for interactivity (by this, we mean data that are not already encoded in the image as x-location or y-location). In either case, we begin by inviting the user to supply a variable name or row/column matrix (see below), which contains the data they want displayed, for example in a tooltip.
    1. Require the new data to be in the same order as the objects in the SVG (this is observation order, within each component of a twoway graph, though this does not apply at all to graphs of stats like boxplots). This is easy to code but has limitations and puts the onus on the user.
    2. Allow the new data to be in any order, and to include x-y locations (or maybe, for more advanced users, an id, to match that added by **svgtag**) of the objects to which they relate. This requires us to calculate the data-to-pixel scale so we can find objects within a certain tolerance of the specified location and attach the data. This is more flexible for users, but I'm not sure how many would want to use additional data that were not in a variable. Also, it's not foolproof as there could be more than one object at a location.
    * We are working with option 1 and might expand to option 2, depending on the experience of early adopters.
    * note also that string data (which will usually be the case) has to be in a variable, so if data are plotted multiple times, the variable will need to be longer than _N; in v16+ it can be in a different data frame, but in v14-15 it would have to be created in Mata, and we need to work out how this would then be passed to **d3**
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
* Surely you wouldn't make a graph with two y-axes. Would you? Well, don't do it here. y-axis must be on the left edge of the plotregion and x axis on the bottom edge. (this is because we might read data values from xlabel and ylabel to allow creation of d3 scales e.g. for tooltip values as the mouse moves along a line chart; at present we do not have this functionality and the axis requirement is not enforced.) We make no guarantee of how z-axes and other wacky stuff will affect the output.
* At present, we only deal with circular marker symbols. You can output other shapes and they will be carried through, but we can't apply interactivity to them (yet).
* We don't apply interactivity to lines from Stata versions 14 or 15, as explained above.
* At present, we don't allow grid lines, because they will be interpreted as data in a line chart, but we intend to add the functionality to detect and ignore them. However, this can only be on the basis that there is a <line> element that has ends on the left and right edges of the plotregion and those ends have the same y pixel locations; if you had a genuine line that did that, it would be flagged as a gridline and no interactivity applied. So, we will need an option to turn off the gridline filter. I suspect that the number of people blithely drawing gridlines with s2color scheme is more than those who wish to have specified horizontal lines with interactivity.
* linear scales only (because we read the axis labels to get a data-to-pixel conversion); this could be extended to log scales in future
* our approach to these limitations is *not* to check them but to warn the user that things may well go awry if they do not comply

### Limitations on the D3 interactivity
* We are aiming to have these for September London conference:
    * display text from a string variable alongside or under the graph on hover/click
    * display text from a string variable in a tooltip on hover / click
    * change colour to highlight one class of markers / lines on hover / click / radio button / tickbox; other classes can change too (typically to be faded out); optionally, they can stay highlighted or allow only one class at a time; accompanying text like a title or caption can change too
* We have these on our radar:
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


## What does d3pretagged look for?
* It will ignore Stata version as declared at the top of the SVG file, allowing you to manually edit your SVGs (especially for line-to-path conversion).

### Thank you:
* Brennan Kahan
* Billy Buchanan
