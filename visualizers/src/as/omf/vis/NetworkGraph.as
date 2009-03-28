
package omf.vis

{
  import flare.animate.Transitioner;
  import flare.data.DataSet;
  import flare.display.TextSprite;
  import flare.scale.ScaleType;
  import flare.util.palette.ColorPalette;
  import flare.vis.Visualization;
  import flare.vis.data.Data;
  import flare.vis.data.NodeSprite;
  import flare.vis.data.EdgeSprite;
  import flare.vis.operator.encoder.ColorEncoder;
  import flare.vis.operator.encoder.PropertyEncoder;
  import flare.vis.operator.encoder.ShapeEncoder;
  import flare.vis.operator.filter.GraphDistanceFilter;
  import flare.vis.operator.layout.RadialTreeLayout;
  import flare.util.palette.SizePalette;
  
  import flash.display.Sprite;
  import flash.events.MouseEvent;
  import flash.geom.Rectangle;
  import flash.text.TextFormat;
  //import mx.controls.Text;
  import mx.core.Application;


  /**
   * Demo reading the graph from a graphml file
   *
   * 
   * @author <a href="http://goosebumps4all.net">martin dudek</a>
   */
  
  [SWF(width="600", height="600", backgroundColor="#ffffff", frameRate="30")]
  public class NetworkGraph extends Sprite
  {
    
    private var vis:Visualization;
    private var maxLabelWidth:Number;
    private var maxLabelHeight:Number;
    private var _maxDistance:int = 2;
    private var _transitionDuration:Number = 2;
    private var _gdf:GraphDistanceFilter;
    
    public function 
    NetworkGraph() 
    
    {
//      var ta1:String;
//      var app = Application;
//      for (var i:String in Application.application.parameters) {
//           ta1 += i + ":" + Application.application.parameters[i] + "\n";
//      }

      var gmr:GraphMLReader = new GraphMLReader(onLoaded);
      gmr.read("http://localhost:2000/graph");
    }
      
    
    private function 
    onLoaded(data:Data):void 
    
    {
      vis = new Visualization(data);
      var w:Number = stage.stageWidth;
      var h:Number = stage.stageHeight;
      
      vis.bounds = new Rectangle(0, 0, w, h);
      addChild(vis);
      
      vis.data.nodes.setProperties({lineWidth:1, size: 1.5});

//      var textFormat:TextFormat = new TextFormat();
//      textFormat.color = 0xffffffff;
      vis.data.nodes.visit(function(ns:NodeSprite):void { 
//        var ts:TextSprite = new TextSprite(ns.data.name,textFormat);
//        var ts:TextSprite = new TextSprite("",textFormat);
//        ns.addChild(ts);  
        
        var x:Number = ns.data.x;
        ns.x = x;
        var y:Number = ns.data.y;
        ns.y = y;
      });

      var lwPallette:SizePalette = new SizePalette(1, 10, false);
      var strengthV:ScaleEncoder = new ScaleEncoder("data.strength", Data.EDGES, "lineWidth", 
                                                     lwPallette, ScaleType.LINEAR);
      vis.operators.add(strengthV);
      
// rainbow_by_levels 
//  ! Level    Red  Green   Blue
//        1   80.0    0.0  100.0
//        2   30.0   20.0  100.0
//        3    0.0   60.0   30.0
//        4  100.0  100.0    0.0
//        5  100.0    0.0    0.0
//        6   60.0    0.0    0.0
//   ocean_temp
//   ! SetPt    Red  Green   Blue
//     -2.0   80.0    0.0  100.0 = CC00FF
//      0.0   30.0   20.0  100.0 = 4C33FF
//     10.0    0.0   60.0   30.0 = 00994C
//     20.0  100.0  100.0    0.0 = FFFF00
//     30.0  100.0    0.0    0.0 = FF0000
//     35.0   60.0    0.0    0.0 = 990000
     
      //var colors:Array = [0xFFCC00FF, 0xFF4C33FF, 0xFF00994C, 0xFFFFFF00, 0xFFFF0000, 0xFF990000];
      //var colors:Array = [0xff0000, 0xbb4400, 0x777700, 0x33bb00, 0x00ff00, 0x0];
      var colors:Array = [0x0, 0xFFFFFF00, 0xFFCCFF00, 0xFF99FF00, 0xFF66CC00, 0xFF339900];
      var greenRedPallette:ColorPalette = new ColorPalette(colors);
      var strength2V:ColorEncoder = new ColorEncoder("data.strength", Data.EDGES,
                                                    "lineColor", ScaleType.LINEAR,
                                                    greenRedPallette);
      vis.operators.add(strength2V);
      
      var lay:RadialTreeLayout =  new RadialTreeLayout();
      lay.useNodeSize = false;
      var root:NodeSprite = vis.data.nodes[0];
      _gdf = new GraphDistanceFilter([root], _maxDistance,NodeSprite.GRAPH_LINKS); 
      vis.operators.add(_gdf); //distance filter has to be added before the layout
      
      vis.update();
      updateRoot(root);
    }
    
    
    
    private function 
    update(event:MouseEvent):void 
    
    {
      var n:NodeSprite = event.target as NodeSprite;
      if (n == null) return; 
      updateRoot(n);
    }
    
    private function 
    updateRoot(n:NodeSprite):void 
    
    {
      vis.data.root = n; 
      _gdf.focusNodes = [n];
      
      var t1:Transitioner = new Transitioner(_transitionDuration);
      vis.update(t1).play();
    }
    
    private function 
    getMaxTextLabelWidth():Number 
    
    {
      var maxLabelWidth:Number = 0;
      vis.data.nodes.visit(function(n:NodeSprite):void {
        var w:Number = getTextLabelWidth(n);
        if (w > maxLabelWidth) {
          maxLabelWidth = w;
        }
        
      });
      return maxLabelWidth;
    }
    
    private function 
    getMaxTextLabelHeight():Number 
    
    {
      var maxLabelHeight:Number = 0;
      vis.data.nodes.visit(function(n:NodeSprite):void {
        var h:Number = getTextLabelHeight(n);
        if (h > maxLabelHeight) {
          maxLabelHeight = h;
        }
        
      });
      return maxLabelHeight;
    }
      
    private function 
    getTextLabelWidth(s:NodeSprite) : Number 
    
    {
      var s2:TextSprite = s.getChildAt(s.numChildren-1) as TextSprite; // get the text sprite belonging to this node sprite
      var b:Rectangle = s2.getBounds(s);
      return s2.width;
    }
    
    private function 
    getTextLabelHeight(s:NodeSprite):Number 
    
    {
      var s2:TextSprite = s.getChildAt(s.numChildren-1) as TextSprite; // get the text sprite belonging to this node sprite
      var b:Rectangle = s2.getBounds(s);
      return s2.height;
    }
    
    private function 
    adjustLabel(s:NodeSprite, w:Number, h:Number) : void 
    
    {
      var s2:TextSprite = s.getChildAt(s.numChildren-1) as TextSprite; // get the text sprite belonging to this node sprite
      
      s2.horizontalAnchor = TextSprite.CENTER;
      s2.verticalAnchor = TextSprite.CENTER;
    }
  }
} 

