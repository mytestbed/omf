// ActionScript file

package 

{
  import flash.display.Sprite;
  import omf.vis.NetworkGraph;
  
  
  [SWF(width="600", height="600", backgroundColor="#ffffff", frameRate="30")]
  public class 
  NetworkGraphApp 
    extends Sprite
  {
      private var vis:Object;
      
      public function 
      NetworkGraphApp()
      
      {
        var w:Number = stage.stageWidth;
        var h:Number = stage.stageHeight;
        
        vis = new NetworkGraph();
      }
  }
}

