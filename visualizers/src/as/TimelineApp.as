// ActionScript file

package 

{
  import flare.data.DataSet;
  import flare.data.DataSource;
  import flare.data.DataTable;
  import flare.data.DataSchema;
  import flare.data.DataUtil;
  import flare.data.DataField;
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
      var cfgURL:String = root.loaderInfo.parameters.cfgURL;
      
      if (cfgURL == null) {
        // Should really display an error
        cfgURL = "http://localhost:2000/graphConfig";
      }
      
      var cfgLoader:JSONReader = new JSONReader(onConfigLoaded);
      cfgLoader.read(cfgURL);        
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
      
      switch(format) {
        case("xml") :
          var ds:DataSource = new DataSource(cfg["url"], format);
          var loader:URLLoader = ds.load();
          loader.addEventListener(Event.COMPLETE, function(evt:Event):void {
            var ds:DataSet = loader.data as DataSet;
            onDataLoaded(Data.fromDataSet(ds));
          });
          break;
          
        case("json"):
          var cfgLoader:JSONReader = new JSONReader(onJSONDataLoaded);
          cfgLoader.read(cfg["url"]);
          break;
      }
        
    }
      
    private function
    onJSONDataLoaded(jsonObj:Object):void
    
    {
      var rows:Array;
      var schema:DataSchema;
      
      if (!jsonObj.hasOwnProperty("oml_res")) {
        throw new ConfigError("Unknown result set. Doesn't start with 'omf_res'.");
      }
      
      var resObj:Object = jsonObj["oml_res"];
      
      if (!resObj.hasOwnProperty("columns")) {
        throw new ConfigError("Missing 'columns' declaration");
      }
      if (!resObj.hasOwnProperty("rows")) {
        throw new ConfigError("Missing 'data' declaration");
      }
      

      rows = resObj["rows"];

//      schema = inferSchema(resObj["columns"], rows);
//      var ds:DataSet = new DataSet(new DataTable(rows, schema));
//      onDataLoaded(Data.fromDataSet(ds));
      
      var cols:Array = resObj["columns"];
      var data:Data = new Data();
      var l:uint = cols.length;
      for each (var row:Array in rows) {
        var n:Object = new Object();
        for (var i:uint = 0; i < l; i++) {
          var key:String = cols[i]
          var value:Object = row[i]
          n[key] = value;
        }
        data.addNode(n);
      }
      onDataLoaded(data);
    }
    
    /**
     * Infers the data schema by checking values of the input data.
     * @param lines an array of lines of input text
     * @return the inferred schema
     */
    protected function 
    inferSchema(cols:Array, rows:Array):DataSchema
    
    {
      var header:Array = cols;
      var types:Array = new Array(header.length);
      
      // initialize data types
      var tok:Array = rows[0];
      for (var col:int=0; col<header.length; ++col) {
        types[col] = DataUtil.type(tok[col]);
      }
      
//      // now process data to infer types
//      for (var i:int = 2; i < rows.length; ++i) {
//        tok = rows[i];
//        for (col=0; col<tok.length; ++col) {
//          if (types[col] == -1) continue;
//          var type:int = DataUtil.type(tok[col]);
//          if (types[col] != type) {
//            types[col] = -1;
//          }
//        }
//      }
      
      // finally, we create the schema
      var schema:DataSchema = new DataSchema();
      schema.hasHeader = true;
      for (col=0; col < header.length; ++col) {
        schema.addField(new DataField(header[col],
          types[col]==-1 ? DataUtil.STRING : types[col]));
      }
      return schema;
    }

  }
}
