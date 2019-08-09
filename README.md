Stata2D3
================

*The master branch of this repo is work in progress over summer 2019. We will launch at Stata's London conference in September. Until then, you are advised not to rely on it to work in any way whatsoever!*

## Overview

This is a collection of Stata commands that allow you to export your Stata graphics into an interactive webpage. Essentially, it saves your graph as SVG format, annotates that, wraps it in an HTML file with link to the [D3](https://d3js.org) JavaScript library, and if you wish, it adds some D3 code to give you a little interactivity. It requires Stata versions 14+ (but see below).
Here's some examples:
* *these are aspirational notes of work in progress*
* sysuse auto, clear
* d3, hover_tooltip(make): scatter price mpg


## Commands
**svgtag** takes an SVG graph file exported by Stata, scans it for objects ike the plot region, axes, axis titles, gridlines, circles and lines inside the plotregion, and so on. Once it has found those, it adds *ids* and *classes* (which we collectively call "tags" here, much to the horror of full-stack rockstar web devz), which help D3 keep track of what's going on, and what it can change or interact with inside the SVG.
It can only work with SVG exported by Stata because those files follow a clearly specified structure, and **svgtag** uses that structure to find its way around; you can't feed files from other software into it, nor can you amend your Stata SVG in Inkscape or Illustrator, and then plug it into **svgtag**.

**d3** is a prefix, so there are options before the colon specific to interaction in the browser, and after the colon you supply a standard Stata graph-making command. Whatever is in the active graph window is then exported to a temporary SVG format file. **svgtag** is called in the background

**d3pretagged** does all the actions of **d3**, starting from the point after **svgtag** has run. You could use this if there are some quirks in your graph that mean it would be easier to tag it manually (or adjust it after running **svgtag**). You can find the complete list of features that **d3pretagged** will look for in an SVG file below.

There are some other SVG-manipulating commands at [stata-svg](https://github.com/robertgrant/stata-svg) that you might find useful.



## Limitations
Stata2D3 aims to get as close as possible to one monolithic program to make interactive content from any Stata graph. You might well argue that this is foolish, and we don't entirely disagree. It is intended as a stepping stone, to help people make something quickly that they can then edit, or give to web developers, or to help them learn about SVG and JavaScript. It is never going to do everything for you.
> The longest of journeys begins with a single HTML file
— *Stephen Senn (apocryphal)*

Clearly, there are a gazillion ways you can make a Stata graph, so there are limitations on what you can feed into it. There are also a frazillion ways you can use interactivity, so we just supply the most common ones and leave it to you to tweak the resulting combination of SVG, HTML and JavaScript. To describe each of these in turn:
### Limitations on the Stata graphs
* All graphs must have axes, even if they are invisible
* Axes may not be inside the plotregion (a horizontal axis at zero in the middle of the graph, for example). You can add them later but any line inside the plotregion might be misinterpreted as data
* Surely you wouldn't make a graph with two y-axes. Would you? Well, don't do it here.
* At present, we only deal with circular marker symbols. You can output other shapes and they will be carried through, but we can't apply interactivity to them (yet).
* At present, we don't allow grid lines, but we intend to add them
* linear scales only (because we read the axis labels to get a data-to-pixel conversion); this could be extended to log scales in future

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
* These are interesting but perhaps too hard to provide in a generic function:
    * a collection of graphs (via **graph** **combine** perhaps) that filter each other by rectangle selection in the manner of crossfilter.js
    * see also the note below on D3 axes and scales

* At present, the SVG is written into the HTML, so you can't use D3 functionality that relies on axes, scales and so forth. This rules out zooming. Anything that just interacts with a DOM object (and, potentially, changes that one object or others of its class) will be fine. We might consider a translator to D3 axes in due course, but right now, we're not convinced of its merits in the scenario where you want a Stata graph reproduced. Feel free to try to convince us otherwise.


## Older versions of Stata

There is an older (and very limited) version of Stata2D3 which you can find here in the **pre-svg** branch. That will work with versions of Stata before 14, when SVG output appeared. If you have 14 and up, this **master** branch version is highly recommended: it has vastly more functionality.


## What does d3pretagged look for?
