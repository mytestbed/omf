package omf.vis

{
  
   public class 
   ConfigError 
     extends Error   
   
   {
    /**
     * Constructs a new ConfigError.
     *
     * @param message The error message that occured during parsing
     * @langversion ActionScript 3.0
     * @playerversion Flash 8.5
     * @tiptext
     */
    public function 
    ConfigError(message:String = "")
    
    {
      super( message );
    }
  }
  
}
