function flowSelectAll()

{

	if (typeof(flowSelectArray)=="undefined")

		return true;

	else

		{

		var theList;

		for (a=0;a<flowSelectArray.length;a++){						

			theList = document.getElementById(flowSelectArray[a]);

			 for ( i = 0; i <= theList.length-1; i++ )

			  theList.options[i].selected = false;

			 for ( i = 0; i <= theList.length-1; i++ )

			  theList.options[i].selected = true;

		}

	}

 return true;

} // flowSelectAll()





function redirect( where )

{

  location.href=where;

  return true;

} // End redirect



function doSubmit(r){

	flowSelectAll();

	document.wwv_flow.p_request.value = r;

	document.wwv_flow.submit();

	

} // End doSubmit()



function first_field(field1)

{

    if(document.getElementById){

    	if(document.getElementById(field1)){

    		var theField = document.getElementById(field1);

    		if((theField.type!="hidden")&&(!theField.disabled)){

    			theField.focus();}

      }

	return true;

	}

} // End of first_field()





function charCount(tArea,maxNo,ctrField,maxField,ctrBlock,allowExtra){

	textArea = document.getElementById(tArea);

	ctrF	 = document.getElementById(ctrField);

	maxF	 = document.getElementById(maxField);

	ctrBlk   = document.getElementById(ctrBlock);

	pctFull  = textArea.value.length / maxNo * 100;

	

	if (allowExtra != 'Y')

		{if (textArea.value.length >= maxNo)

			{textArea.value = textArea.value.substring(0, maxNo);

			 textArea.style.color = 'red';

			}

		 else

			{msg = null;

			 textArea.style.color = 'black';}

		}

	ctrF.innerHTML = textArea.value.length;

	maxF.innerHTML = maxNo;

	if (textArea.value.length > 0)

		{ctrBlk.style.visibility = 'visible';}

	else

		{ctrBlk.style.visibility = 'hidden';}

		

	if (pctFull >= 90)

		{ctrBlk.style.color='red';}

	else if (pctFull >= "80")

		{ctrBlk.style.color='#EAA914';}

	else

		{ctrBlk.style.color='black';}

} // End charCount()





function shuttleItem(theSource, theDest, moveAll) {

    srcList  = document.getElementById(theSource);

    destList = document.getElementById(theDest);

    var arrsrcList = new Array();

    var arrdestList = new Array();

    var arrLookup = new Array();

    var i;

    

    if (moveAll){

        for ( i = 0; i <= srcList.length-1; i++ )

			  srcList.options[i].selected = true;

    }

    for (i = 0; i < destList.options.length; i++) {

        arrLookup[destList.options[i].text] = destList.options[i].value;

        arrdestList[i] = destList.options[i].text;}

    var fLength = 0;

    var tLength = arrdestList.length;

    for(i = 0; i < srcList.options.length; i++) {

        arrLookup[srcList.options[i].text] = srcList.options[i].value;

        if (srcList.options[i].selected && srcList.options[i].value != "") {

            arrdestList[tLength] = srcList.options[i].text;

            tLength++;}

        else {

            arrsrcList[fLength] = srcList.options[i].text;

            fLength++;}

    }

    arrsrcList.sort();

    arrdestList.sort();

    srcList.length = 0;

    destList.length = 0;

    var c;

    for(c = 0; c < arrsrcList.length; c++) {

        var no = new Option();

        no.value = arrLookup[arrsrcList[c]];

        no.text = arrsrcList[c];

        srcList[c] = no;

    }

    for(c = 0; c < arrdestList.length; c++) {

        var no = new Option();

        no.value = arrLookup[arrdestList[c]];

        no.text = arrdestList[c];

        destList[c] = no;

       }

} // End shuttleItem()





// setStyleByClass: given an element type and a class selector,

// style property and value, apply the style.

// args:

//  t - type of tag to check for (e.g., SPAN)

//  c - class name

//  p - CSS property

//  v - value

var ie = (document.all) ? true : false;



function setStyleByClass(t,c,p,v){

	var elements;

	if(t == '*') {

		// '*' not supported by IE/Win 5.5 and below

		elements = (ie) ? document.all : document.getElementsByTagName('*');

	} else {

		elements = document.getElementsByTagName(t);

	}

	for(var i = 0; i < elements.length; i++){

		var node = elements.item(i);

		for(var j = 0; j < node.attributes.length; j++) {

			if(node.attributes.item(j).nodeName == 'class') {

				if(node.attributes.item(j).nodeValue == c) {

					eval('node.style.' + p + " = '" +v + "'");

				}

			}

		}

	}

}

// End setStyleByClass()



// e - element id

// s - style

// v - value

// setStyle('P100_NAME','display','none') hides item P100_NAME

function setStyle(e,s,v){

    theItem = document.getElementById(e);

    eval('theItem.style.'+ s + " = '" + v + "'");

}



function popupURL(url)

{w = open(url,"winLov","Scrollbars=1,resizable=1,width=800,height=600");

if (w.opener == null)

w.opener = self;

w.focus();}

    

function confirmDelete(msg,req){

    if(req==null){req='Delete'}

    var confDel = msg;

    if(confDel ==null){

        confDel= confirm("Would you like to perform this delete action?");}

    else{

        confDel= confirm(msg);}

    if (confDel== true){

        doSubmit(req);}

}



// use for popups in which you want the page to close after delete

function confirmDelete2(msg,req){

    if(req==null){req='Delete'}

    var confDel = msg;

    if(confDel ==null){

        confDel= confirm("Would you like to perform this delete action?");}

    else{

        confDel= confirm(msg);}

    if (confDel== true){

        doSubmit(req);

        window.close();

     }

}



function submitEnter(itemObj,e){

    var keycode;

    if (window.event) keycode = window.event.keyCode;

    else if (e) keycode = e.which;

    else return true;

    

    if (keycode == 13)

       {

       doSubmit(itemObj.id);

       return false;

       }

    else

       return true;

}



// written to hide/show region a region body, 

// should support other uses

// on null display attribute assumes it's hidden by the class

function hideShow(objectID,imgID,showImg,hideImg){

    theImg = document.getElementById(imgID);

    theDiv = document.getElementById(objectID);

    if(theDiv.style.display == 'none' || theDiv.style.display == '' || theDiv.style == null){

        theImg.src = hideImg;

        document.getElementById(objectID).style.display = 'block';}

    else{

        theImg.src = showImg;

        document.getElementById(objectID).style.display = 'none';}

    return;

}



//Get a value from a cookie

function getCookieVal (offset) 

   {

   var endstr = document.cookie.indexOf (";", offset);

   if (endstr == -1)

      endstr = document.cookie.length;

   return unescape(document.cookie.substring(offset, endstr));

   }



//Get a cookie and it's value

function GetCookie (name) 

   {

   var arg = name + "=";

   var alen = arg.length;

   var clen = document.cookie.length;

   var i = 0;

   while (i < clen) 

      {

      var j = i + alen;

      if (document.cookie.substring(i, j) == arg)

         return getCookieVal (j);

      i = document.cookie.indexOf(" ", i) + 1;

      if (i == 0) break; 

      }

   return null;

   }

//Set a cookie and it's value

function SetCookie (name, value) 

   {

   var argv = SetCookie.arguments;

   var argc = SetCookie.arguments.length;

   var expires = (argc > 2) ? argv[2] : null;

   var path = (argc > 3) ? argv[3] : null;

   var domain = (argc > 4) ? argv[4] : null;

   var secure = (argc > 5) ? argv[5] : false;

   document.cookie = name + "=" + escape (value) +

        ((expires == null) ? "" : ("; expires=" + expires.toGMTString())) +

        ((path == null) ? "" : ("; path=" + path)) +

        ((domain == null) ? "" : ("; domain=" + domain)) +

        ((secure == true) ? "; secure" : "");

   }

// Used for quick edit links

function quickLinks(what){

    if (what == 'HIDE'){

        setStyleByClass('a','eLink','display','none'); 

        setStyleByClass('img','eLink','display','none');    

        setStyle('hideEdit','display','none');

        setStyle('showEdit','display','inline');

        SetCookie('MarvelQuickEdit',what);}

    else{

        setStyleByClass('a','eLink','display','inline'); 

        setStyleByClass('img','eLink','display','inline');  

        setStyle('hideEdit','display','inline');

        setStyle('showEdit','display','none');

        SetCookie('MarvelQuickEdit',what);}            

}



function popupFieldHelp(curentItemId, sessionId, closeButtonName){

    if (arguments[2])

        var closeButton = '&p_close_button_name='+closeButtonName;

    else

        var closeButton = '';

    w = open("wwv_flow_item_help.show_help?p_item_id=" + curentItemId + "&p_session=" + sessionId+closeButton,"winhelp","Scrollbars=1,resizable=1,width=500,height=350");

    if (w.opener == null)

    w.opener = self;

    w.focus();

}



function popUp2(URL,width,height) {

 day = new Date();

 id = day.getTime();

 eval("page" + id + " = window.open(URL, '" + id + "', 'toolbar=0,scrollbars=1,location=0,statusbar=0,menubar=0,resizable=1,width='+width+',height='+height);");

 }

 

 

/*

start 

ask user to navigate off of the page

*/

var htmldb_ch=false;  

   

 function htmldb_item_change(t){  

 if (htmldb_ch == false){  

 htmldb_ch=true;   

 }  

 }  

   

 function htmldb_goSubmit(r){  

     if(htmldb_ch){

		if (!htmldb_ch_message || htmldb_ch_message == null){

            htmldb_ch_message='Are you sure you want to leave this page without saving? /n Please use translatable string.'}

        

        if (window.confirm(htmldb_ch_message)) doSubmit(r);

        

        }  

     else{



         doSubmit(r);  

     }  

     return;      

 }  

/*

end 

ask user to navigate off of the page

*/ 

