// Disclaimation:
// *************
// This program is written by Wuyin Lin (wlin@msrc.sunysb.edu).
// It is freely re-distributable. The author assumes no obligation for the
// stability and accuracy of the code.
//
// This version is intended for simultaneously displaying multiple panels

// -----------------------------------------------------------------------
// Browser Detection
isMac = (navigator.appVersion.indexOf("Mac")!=-1) ? true : false;
NS4 = (document.layers) ? true : false;
IEmac = ((document.all)&&(isMac)) ? true : false;
IE4plus = (document.all) ? true : false;
IE4 = ((document.all)&&(navigator.appVersion.indexOf("MSIE 4.")!=-1)) ? true : false;
IE5 = ((document.all)&&(navigator.appVersion.indexOf("MSIE 5.")!=-1)) ? true : false;
ver4 = (NS4 || IE4plus) ? true : false;
NS6 = (!document.layers) && (navigator.userAgent.indexOf('Netscape')!=-1)?true:false;
var frame = 0;         // keep track of what frame of the animation we're on.
var timeout_id = null; // allows us to stop the animation.
var num_loaded_images = 0;
var pauseStatus = 0;

var colPerRow = 2;

function initialize(iniImage) {
var doc = document;
var colPerRowM1 = colPerRow - 1;
doc.writeln("<center>");
var imglen = iniImage.length;

framePerPage = imglen;

var i = 0;
doc.writeln("<table>");

for(i=0;i<imglen;i++) {
   if(i % colPerRow == 0) doc.writeln("<tr>");
   doc.writeln("<td>");
if(IE4plus || NS6) {
  doc.writeln("<DIV ID=figcaption"+i+" NAME=figcaption"+i+">&nbsp;&nbsp;</DIV>");
}else if(NS4) {
  doc.writeln("<LAYER ID=figcaption"+i+"><center>&nbsp;&nbsp;<center></LAYER><br>");
}
//-- The image that will be animated.  Give it a name for convenience -->
//   doc.writeln("<IMG SRC='"+iniImage[i]+"' NAME=animation"+i+" width=500>");
   doc.writeln("<IMG SRC='"+iniImage[i]+"' NAME=animation"+i);
   doc.writeln("</td>");
   if(i % colPerRow == colPerRowM1) doc.writeln("</tr>");
}
doc.writeln("</table>");
doc.writeln("</center>");
//setcaption(0);
}

function setcaption(frame) {
    if(IE4plus){ 
         figcaption.innerHTML = figCaptions[frame] 
    }
    else if (NS4){
       var docfig = document.figcaption.document;
       docfig.open();
       docfig.writeln("<center>");
       docfig.writeln(figCaptions[frame]);
       docfig.writeln("</center>");
       docfig.close();
    } else if(NS6) {
       document.getElementById("figcaption").innerHTML = figCaptions[frame];
    }
}
function animate()  // The function that does the animation.
{
    for(var i=0; i< framePerPage; i++)
    document.images['animation'+i].src = images[frame*framePerPage+i].src;
//    setcaption(frame);
    frame = (frame + 1)%frameSize;
    if(frame == 0)  // on starting over
       timeout_id = setTimeout("animate()", (3*timeStepping>3000)?3*timeStepping:3000);  // display next frame later
    else
       timeout_id = setTimeout("animate()", timeStepping);  // display next frame later
}
function setframe(frame)  // The function that does the animation.
{
    for(var i=0; i< framePerPage; i++)
    document.images['animation'+i].src = images[frame*framePerPage+i].src;
//    setcaption(frame);
}

function getnext(direction)  // The function that does the animation.
{
    frame = (frame + direction+frameSize)%frameSize;
    for(var i=0; i< framePerPage; i++)
    document.images['animation'+i].src = images[frame*framePerPage+i].src;
//  setcaption(frame);
}
// Count how many images have been loaded.  When we reach 10, start animating
function count_images() {  if (++num_loaded_images == totFrameSize) animate(); }

// when using NS4, and using functions, num_loaded_images may be 1 less
// moreover, when using loadNstart, may need to press 'Play' to start
// typically, this is because the count of image loading is lost
// may want to find other approach for it.

function ctrlButtons() {
document.writeln('<FORM>');
document.writeln('  <INPUT TYPE=button VALUE="Play" ');
document.writeln('         onClick="timeStepping = timeSteppingSav; if (!timeout_id && num_loaded_images>=frameSize-1) animate();">');
document.writeln('  <INPUT TYPE=button VALUE="Pause" ');
document.writeln('         onClick="if (timeout_id) clearTimeout(timeout_id); timeout_id=null;if(pauseStatus){animate();pauseStatus=0} else pauseStatus = 1;">');
document.writeln('  <INPUT TYPE=button VALUE="Stop" ');
document.writeln('         onClick="if (timeout_id) clearTimeout(timeout_id); timeout_id=null;frame=0;">');
document.writeln('  <INPUT TYPE=button VALUE="Reset" ');
document.writeln('         onClick="if (timeout_id) clearTimeout(timeout_id); timeout_id=null;frame=0;setframe(frame)">');
document.writeln('  <INPUT TYPE=button VALUE="Prev" ');
document.writeln('         onClick="if (timeout_id) clearTimeout(timeout_id); timeout_id=null;getnext(-1);">');
document.writeln('  <INPUT TYPE=button VALUE="Next" ');
document.writeln('         onClick="if (timeout_id) clearTimeout(timeout_id); timeout_id=null;getnext(1);">');
document.writeln('  <INPUT TYPE=button VALUE="Slow" ');
document.writeln('         onClick="if(timeStepping < timeSteppingSav) timeStepping = timeSteppingSav;timeStepping *= 1.20;">');
document.writeln('  <INPUT TYPE=button VALUE="Fast" ');
document.writeln('         onClick="if(timeStepping > timeSteppingSav) timeStepping = timeSteppingSav;timeStepping *= 0.80;">');
document.writeln('</FORM>');
}

function loadNstart() {
// Create the off-screen images and assign the image URLs.
// Also assign an event handler so we can count how many images have been
// loaded.  Note that we assign the handler before the URL, because otherwise
// the image might finish loading (if it is already cached, e.g.) before
// we assign the handler, and then we'll lose count of how many have loaded!
   var nd1 = imgsrc.length;
   var nd2 = imgsrc[0].length;
   images = new Array(nd1*nd2);
   frameSize = nd1 ;// size of each panel
   totFrameSize = images.length;
   var k = 0;
   for(var i=0; i< nd1; i++) 
   for(var j=0; j< nd2; j++) {
       images[k] = new Image();                 // Create an Image object
       images[k].onload = count_images;         // assign the event handler
       images[k].src = imgsrc[i][j];  // tell it what URL to load
       k++;
   }
}