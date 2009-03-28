/** 
 * simple graphml reader utility
 * 
 */ 

package omf.vis

{
//  import flare.data.converters.GraphMLConverter;
//  import flare.data.DataSet;
  import flash.events.*;
  import flash.net.*;
  import com.adobe.serialization.json.JSON
  
  public class 
  JSONReader
  
  {
    public var _onComplete:Function;
  
    public function 
    JSONReader(
      onComplete:Function=null,
      file:String = null
    ) {
      _onComplete = onComplete;
  
      if(file != null) {
        read(file);
      }
    }
    
    public function 
    read(file:String):void 
    
    {
      if ( file != null) {
        var loader:URLLoader = new URLLoader();
        configureListeners(loader);
        var request:URLRequest = new URLRequest(file);
        try {
          loader.load(request);
        } catch (error:Error) {
          trace("Unable to load requested document.");
        }
      }
    }
  
    private function 
    configureListeners(dispatcher:IEventDispatcher):void 
    
    {
      dispatcher.addEventListener(Event.COMPLETE, completeHandler);
      dispatcher.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
      dispatcher.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
    }
  
    private function 
    completeHandler(event:Event):void 
    
    {
      if (_onComplete != null) {
        var loader:URLLoader = event.target as URLLoader;
        var obj:Object = JSON.decode(loader.data);
        //var dataSet:DataSet = new GraphMLConverter().parse(new XML(loader.data));
        _onComplete(obj);
      } else {
        trace("No onComplete function specified.");
      }
    }
  
    private function 
    securityErrorHandler(event:SecurityErrorEvent):void 
    
    {
      trace("securityErrorHandler: " + event);
    }
  
     
    private function 
    ioErrorHandler(event:IOErrorEvent):void 
    
    {
      trace("ioErrorHandler: " + event);
    }
  }
}