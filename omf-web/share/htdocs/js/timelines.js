

var timeline_;
var timeline_source_ = "/browse/timeline";

addLoadEvent(function() {
  var eventSource = new Timeline.DefaultEventSource();
  var bandInfos = [
    Timeline.createBandInfo({
        eventSource:    eventSource,
//        date:           "Jun 28 2006 00:00:00 GMT",
        width:          "70%", 
//        intervalUnit:   Timeline.DateTime.MONTH, 
        intervalUnit:   Timeline.DateTime.DAY, 
        intervalPixels: 100
    }),
    Timeline.createBandInfo({
        showEventText:  false,
        trackHeight:    0.5,
        trackGap:       0.2,
        eventSource:    eventSource,
//        date:           "Jun 28 2006 00:00:00 GMT",
        width:          "15%", 
//        intervalUnit:   Timeline.DateTime.YEAR, 
        intervalUnit:   Timeline.DateTime.MONTH, 
        intervalPixels: 200
    }),
    Timeline.createBandInfo({
        showEventText:  false,
        trackHeight:    0.5,
        trackGap:       0.2,
        eventSource:    eventSource,
//        date:           "Jun 28 2006 00:00:00 GMT",
        width:          "15%", 
        intervalUnit:   Timeline.DateTime.YEAR, 
        intervalPixels: 200
    })
  ];
  bandInfos[1].syncWith = 0;
  bandInfos[1].highlight = true;
  bandInfos[2].syncWith = 1;
  bandInfos[2].highlight = true;
  
  timeline_ = Timeline.create(document.getElementById("browse-timeline"), bandInfos);
  Timeline.loadXML(timeline_source_, function(xml, url) { eventSource.loadXML(xml, url); });
});


addResizeEvent(function() {
  if (resizeTimerID == null) {
    resizeTimerID = window.setTimeout(function() {
      resizeTimerID = null;
      timeline_.layout();
    }, 500);
  }
});

Timeline.DefaultEventSource.Event.prototype.fillInfoBubble =
    function(elmt, theme, labeller) {
        var doc = elmt.ownerDocument;
        
        var title = this.getText();
        var link = this.getLink();
        var image = this.getImage();
        
        if (image != null) {
            var img = doc.createElement("img");
            img.src = image;
            
            theme.event.bubble.imageStyler(img);
            elmt.appendChild(img);
        }
        
        var divTitle = doc.createElement("div");
        var textTitle = doc.createTextNode(title);
        if (link != null) {
            var a = doc.createElement("a");
            a.href = link;
            a.appendChild(textTitle);
            divTitle.appendChild(a);
        } else {
            divTitle.appendChild(textTitle);
        }
        theme.event.bubble.titleStyler(divTitle);
//        elmt.appendChild(divTitle);
        
        var divBody = doc.createElement("div");
        this.fillDescription(divBody);
        theme.event.bubble.bodyStyler(divBody);
        elmt.appendChild(divBody);
        
        var divTime = doc.createElement("div");
        this.fillTime(divTime, labeller);
        theme.event.bubble.timeStyler(divTime);
//        elmt.appendChild(divTime);
        
        var divWiki = doc.createElement("div");
        this.fillWikiInfo(divWiki);
        theme.event.bubble.wikiStyler(divWiki);
        elmt.appendChild(divWiki);
    };
