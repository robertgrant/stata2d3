Stata2D3
================

In 2014, I started writing some Stata commands to create [D3](http://d3js.org) interactive graphics for the browser. Then I thought that a bigger project, wrapping them up in one overarching megacommand **-d3-** would be neat. You would type a standard Stata graphics command, prefix it with d3 and boom rudeboy! a self-contained .html file would appear with all the JavaScript, SVG and such in there. It would be hard work but worthwhile.

But I also knew there might be Stata SVG graph outputs one day. I kept asking for it, and I wasn't the only one, and it was relatively easy for them to do. So when they sneaked it out in version 14, I stuck Stata2D3 on ice. Originally, it had to write a lot of SVG to look like your Stata graph, and that is, frankly, hard work. Now, it can take the SVG and smash some sweet D3 particles into that to transmute it into interactive goodness.

So that's the next stage of Stata2D3. I have some other stuff to finish in 2017, then I will attack it in Q1 '18. Look out for a presentation at London SUG '18 if the good Lord spares me etc. It will require version 14 and up, and it will progress pretty quickly. Once the standard graphs work OK (there are many such formats, so that's not trivial to check), I'll start adding other stuff that you can't do in Stata, like hexbins and interactive maps. 
