// ActionScript file

package 

{
  import flare.data.DataSet;
  import flare.data.DataSource;
  import flare.vis.data.Data;
  
  import flash.display.Sprite;
  import flash.events.Event;
  import flash.geom.Rectangle;
  import flash.net.URLLoader;
  
  import omf.vis.ConfigError;
  import omf.vis.JSONReader;
  import omf.vis.Timeline;
  
  
  [SWF(width="600", height="600", backgroundColor="#ffffff", frameRate="30")]
  public class 
  TimelineApp 
    extends Sprite
  {
    private var _visType:String;
    private var _visConfig:Object;
    private var _vis:Timeline;
    
    public function 
    TimelineApp()
    
    {
      var cfgLoader:JSONReader = new JSONReader(onConfigLoaded);
      cfgLoader.read("http://localhost:2000/graphConfig");        
      //loadData();
    }
    
    private function 
    onConfigLoaded(cfgObj:Object):void 
  
    {
      if (!cfgObj.hasOwnProperty("omf_vis")) {
        throw new ConfigError("Unknown configuration declaration. Doesn't start with 'omf_vis'.");
      }
      
      var cfg:Object = cfgObj["omf_vis"];
      
      if (!cfg.hasOwnProperty("type")) {
        throw new ConfigError("Missing 'type' declaration");
      }
      _visType = cfg["type"];
      
      if (!cfg.hasOwnProperty("data")) {
        throw new ConfigError("Missing 'data' declaration");
      }
  
      if (!cfg.hasOwnProperty("config")) {
        throw new ConfigError("Missing 'config' declaration");
      }
      _visConfig = cfg["config"];
      
      loadData(cfg["data"]);
  
    }
    
    private function 
    onDataLoaded(data:Data):void 
  
    {
      showTimeline(data, _visConfig);
    }
    
    private function 
    showTimeline(data:Data, cfgObj:Object):void
    
    {
      var w:Number = stage.stageWidth;
      var h:Number = stage.stageHeight;
      var bounds:Rectangle = new Rectangle(0, 0, w, h);
      
            //var cfg:Object = cfgObj["config"];
      
      _vis = new Timeline(data, cfgObj, bounds);
      addChild(_vis);
    }
      
    private function 
    loadData(cfg:Object):void
    
    {
      if (!cfg.hasOwnProperty("url")) {
        throw new ConfigError("Missing 'type' declaration");
      }
      var url:String = cfg["url"];
      
      var format:String = "tab"
      if (cfg.hasOwnProperty("format")) {
        format = cfg["format"];
      }
      
      var ds:DataSource = new DataSource(cfg["url"], format);
      var loader:URLLoader = ds.load();
      loader.addEventListener(Event.COMPLETE, function(evt:Event):void {
        var ds:DataSet = loader.data as DataSet;
        onDataLoaded(Data.fromDataSet(ds));
      });
    }
      
  }
}
