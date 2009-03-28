package omf.vis

{
	import flare.analytics.optimization.AspectRatioBanker;
	import flare.display.TextSprite;
	import flare.scale.ScaleType;
	import flare.util.Maths;
	import flare.vis.Visualization;
	import flare.vis.data.Data;
	import flare.vis.operator.OperatorList;
	import flare.vis.operator.encoder.ColorEncoder;
	import flare.vis.operator.encoder.PropertyEncoder;
	import flare.vis.operator.layout.AxisLayout;
	
	import flash.display.Sprite;
	import flash.geom.Rectangle;
	
	/**
	 * Demo showcasing a timeline layout (and a bad idea). 
	 */
	public class 
	Timeline
	  extends Sprite
	{
		private var vis:Visualization;
		private var _bounds:Rectangle;
		private var banker:AspectRatioBanker;
		private var _opList:OperatorList;
		
		public function 
		Timeline(data:Data, cfgObj:Object, bounds:Rectangle) 
		
		{
      _bounds = bounds.clone();
      _bounds.inflate(-40, -40);
      _bounds.x = 40;
      _bounds.y = 40;
      
      configure(cfgObj);
      //visualize(getTimeline(150,3));
      visualize(data);
		}
		
		private function
		configure(cfg:Object):void
		
		{
		  _opList = new OperatorList();
      configureAxis(cfg["axis"]);
      configureEncoders(cfg["encoders"]);
		  
		}
		
		private function
    configureAxis(cfgObj:Object):void
    
    {
      if (cfgObj== null) return;
      
      var x:Object = cfgObj["x"];
      var y:Object = cfgObj["y"];
      if (x == null || y == null) {
        throw new ConfigError("'x' or 'y' axis declaration required in 'axis' declaration");
      }
      if (x["field"] == null || y["field"] == null) {
        throw new ConfigError("Missing 'field' in either 'x' or 'y' axis declaration");
      }
      var axisL:AxisLayout;
      axisL = new AxisLayout("data." + x["field"], "data." + y["field"]);
      if (x["flush"]) {
        axisL.xScale.flush = true; // tight margins on timeline
      }
      if (y["flush"]) {
        axisL.yScale.flush = true; // tight margins on y axis
      }
      
      _opList.add(axisL);      
    }
		
    private function
    configureEncoders(cfgObj:Object):void
    
    {
      if (cfgObj== null) return;
      
      var encoders:Array = cfgObj as Array;
      for each (var encCfg:Object in encoders) {
        var type:String = encCfg["type"];
        if (type == null) {
          throw new ConfigError("Missing 'type' in 'encoder' declaration");
        }
        switch (type) {
          case "color": configureColorEncoder(encCfg); break;
          case "property": configurePropertyEncoder(encCfg); break;
          default:
            throw new ConfigError("Unknown encoder '" + type + "'.");
        }
      }
    }
    
    private function
    configureColorEncoder(cfgObj:Object):void
    
    {
      var source:String = null;
      var group:String = null;
      var target:String = null;
      var scaleType:String = null;
      //var palette:ColorPalette = null;
      
      for (var key:String in cfgObj) {
        switch (key) {
          case "type": break;
          case "source": source = cfgObj[key]; break;
          case "group": 
            group = configureGroup(cfgObj[key]);
            break;
          case "target": target = cfgObj[key]; break;
          case "scaleType": 
            scaleType = configureScaleType(cfgObj[key]); 
            break;
          default:
            throw new ConfigError("Unknown property '" + key + "' in color encoder declaration.");
        }
      }
      var enc:ColorEncoder;
      enc = new ColorEncoder("data." + source, group, target, scaleType);
      _opList.add(enc);      
    }
    
    private function
    configureGroup(name:String):String
    
    {
      var group:String = null;
      
      switch (name) {
        case "nodes": group = Data.NODES; break
        case "edges": group = Data.EDGES; break;
        default:
          throw new ConfigError("Unknown group '" + name + "' in encoder declaration.");
      } 
      return group;
    }
    
    private function
    configureScaleType(name:String):String
    
    {
      switch (name) {
        case ScaleType.CATEGORIES: break;
        case ScaleType.LINEAR: break;
        case ScaleType.LOG: break;
        case ScaleType.ORDINAL: break;
        case ScaleType.QUANTILE: break;
        case ScaleType.ROOT: break;
        case ScaleType.TIME: break;
        case ScaleType.UNKNOWN: break;
        default:
          throw new ConfigError("Unknown scale type '" + name + "' in encoder declaration.");
      }
      return name;
    }
    
    private function
    configurePropertyEncoder(cfgObj:Object):void
    
    {
      var values:Object = {};
      var group:String = Data.NODES

      for (var key:String in cfgObj) {
        switch (key) {
          case "type": break;
          case "group": 
            group = configureGroup(cfgObj[key]);
            break;
          default:
            values[key] = cfgObj[key];
        }
      }
      
      var pe:PropertyEncoder;
      pe = new PropertyEncoder(values, group);
      _opList.add(pe);      
    }
		
    private function 
    visualize(data:Data):void 
    
    {
//      vis = new Visualization(data);
//      vis.bounds = _bounds.clone();
//      var axisL:AxisLayout;
//      
//			// timeline visualization definition
//			var timeline:OperatorList = new OperatorList(
//				// the banker automatically selects the visualization
//				// bounds to optimize the perception of trends in the chart
////				banker = new AspectRatioBanker("data.count", true,
////					_bounds.width, _bounds.height),
//				axisL = new AxisLayout("data.date", "data.count"),
//				new ColorEncoder("data.series", Data.EDGES,
//					"lineColor", ScaleType.CATEGORIES),
//				new ColorEncoder("data.series", Data.NODES,
//					"fillColor", ScaleType.CATEGORIES),
//				new PropertyEncoder({
//					lineAlpha: 0, alpha: 0.5, buttonMode: false,
//					scaleX: 1, scaleY: 1, size: 0.5
//				}),
//				new PropertyEncoder({lineWidth:1}, Data.EDGES)
//			);
//			axisL.xScale.flush = true; // tight margins on timeline
			
			
			// create the visualization
			vis = new Visualization(data);
      //vis.operators.add(timeline);
      vis.operators.add(_opList);

			with (vis.xyAxes.xAxis) {
				// position axis labels along timeline
				horizontalAnchor = TextSprite.MIDDLE; // TextSprite.LEFT;
				verticalAnchor = TextSprite.MIDDLE;
				//labelAngle = Math.PI / 2;
			}
			var b:Rectangle = _bounds.clone();
			b.x = b.y = 0; 
			vis.bounds = b;
			
      // set visualization bounds and update axes
      vis.setAspectRatio(1.0 * b.width / b.height, b.width, b.height);
      //vis.axes.update(t);

			vis.update();
			vis.x = _bounds.x;
			vis.y = _bounds.y;
			addChild(vis);
			
//			if (vis.operators[0].index != 0) {
//				vis.continuousUpdates = false;
//				vis.operators[0].index = 0;
//				vis.controls.clear();
//				
//				// update, and delay axis visibility to after the update
//				var t:Transitioner = vis.update(1.5);
//				t.$(vis.axes).alpha = 0;
//				t.$(vis.axes).visible = false;
//				t.addEventListener(TransitionEvent.END,
//					function(evt:TransitionEvent):void {
//						forces.showAxes(new Transitioner(0.5)).play();
//					}
//				);
//				t.play();
//			}
			
		}
		
		public function resize():void
		{
			_bounds.width -= 80;
			_bounds.height -= 80;
			if (vis) {
				vis.bounds = _bounds.clone();
				banker.maxWidth = _bounds.width;
				banker.maxHeight = _bounds.height;
				if (!vis.continuousUpdates) {
					vis.update();
				}
			}
		}
				
		public static function getTimeline(N:int, M:int):Data
		{
			var MAX:Number = 60;
			var t0:Date = new Date(1979,5,15);
			var t1:Date = new Date(1982,2,19);
			var x:Number, f:Number;
			
			var data:Data = new Data();
			for (var j:uint=0; j<M; ++j) {
				for (var i:uint=0; i<N; ++i) {
					f = i/(N-1);
					x = t0.time + f*(t1.time - t0.time);
					data.addNode({
						series: int(j),
						date: new Date(x),
						count:int((j*MAX/M) + MAX/M * (1+Maths.noise(13*f,j)))
					});
				}
			}
			// create timeline edges connecting items sorted by date
			// and grouped by series
			//data.createEdges("data.date", "data.series");
			//data.createEdges("data.date");

			return data;
		}
		
	} // end of class Timeline
}