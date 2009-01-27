function changeLine(line) {
  var red = Math.round(Math.random() * 255);
  var green = Math.round(Math.random() * 255);
  var blue = Math.round(Math.random() * 255);
  changeAttr(line,"stroke","rgb("+ red +","+ green+","+blue+")");


  /*
  var el = document.getElementById(line);
  el.setAttributeNS(null,"stroke","rgb("+ red +","+ green+","+blue+")");
  $(line).setAttributeNS(null,"stroke","rgb("+ red +","+ green+","+blue+")");
  */

}
function changeWidth(line) {
  var w = Math.round(Math.random() * 10);
  changeAttr(line,"stroke-width",w);

  /*
  var el = document.getElementById(line);
  el.setAttributeNS(null,"stroke-width",w);
  */
}

function changeAttr(elName, attrName, value) {
  $(elName).setAttributeNS(null,attrName,value);
}

function changeAttr2(elName, attrs) {
  el = $(elName);
  for(var name in attrs) {
    value = attrs[name];
    info(name + ": " + value + "\n11");
    el.setAttributeNS(null,name,value);
  }
  //  
}



