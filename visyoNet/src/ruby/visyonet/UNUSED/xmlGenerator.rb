
class XMLGenerator  
  def initialize()
#    @visDataModel = ::VisMapping.new()
  end
  
  def getUpdates()
    #puts "XMLGenerator: getUpdates"
    visData=@visDataModel.getUpdates()
    #puts "XMLGenerator: getUpdates - returning something..."
    return createUpdateXML(visData)
  end
  
  def getAllNodes()
    visData=@visDataModel.getAllNodes()
    return createAllNodesXML(visData)
  end

  #Here is a choice either we get the instance
  #of the DBQueryManager and set the appropriate
  #variables or either pass it down the model.
  #Nicu I am adopting the second approach
  #updates anyway have to travel all the way down
  
  #get the next set of updates after the
  #current timestamp + averaging interval
  def stepPlus()
    visData=@visDataModel.stepPlus()
    return createUpdateXML(visData)
  end
  
  #get the prev set of updates before the
  #current timestamp - averaging interval
  def stepMinus()
    visData=@visDataModel.stepMinus()
    return createUpdateXML(visData)
  end
  
  #stop will reset the current timestamp
  # to initial timestamp
  def stop()
    @visDataModel.stop()
    return createStopXML()
  end
  
  #pause will store the current timestamp
  def pause()
    @visDataModel.pause()
    return createPauseXML()
  end
  
  def createUpdateXML(visData)
    # visData is of type VisData
  
    ret="<update>"
    
    # nodes
    
    if (visData != nil)
      # links
      if(visData.VisLinks != nil) 
        # figure out how many shapes a link has - just look at the first one
        # and that is how many layers we have for the links
        nrLayers = visData.VisLinks[visData.VisLinks.keys[0]].shapes.size
        #puts "number of shapes for links: " + nrLayers.to_s
        for i in 0 .. (nrLayers - 1)
          ret = ret + "<layer>"
          visData.VisLinks.each { | id, vislink | 
            #puts vislink.shapes[0]
            ret = ret + vislink.shapes[i].to_XML()
          }
          ret = ret + "</layer>"
        end
      end # if vislinks is not nil
			
			# nodes
			if(visData.VisNodes != nil) 
        # figure out how many shapes a node has - just look at the first one
        # and that is how many layers we have for the nodes
        nrLayers = visData.VisNodes[visData.VisNodes.keys[0]].shapes.size
        
        for i in 0..nrLayers-1
          ret = ret + "<layer>"
          visData.VisNodes.each { | id, visnode | 
            ret = ret + visnode.shapes[i].to_XML()
          }
          ret = ret + "</layer>"
        end
      end
      
      
      
    end # if visdata != nil 
    
    ret = ret + "</update>\0"
    
    #print out the ret xml
    #puts ret
    
    return ret
  end

  def createAllNodesXML(visData)
    # visData is of type VisData
  
    ret="<initialize>"
    
    # nodes
    
    if (visData != nil)
      if(visData.VisNodes != nil) 
        # figure out how many shapes a node has - just look at the first one
        # and that is how many layers we have for the nodes
        nrLayers = visData.VisNodes[visData.VisNodes.keys[0]].shapes.size
        
        for i in 0..nrLayers-1
          ret = ret + "<layer>"
          visData.VisNodes.each { | id, visnode | 
            ret = ret + visnode.shapes[i].to_XML()
          }
          ret = ret + "</layer>"
        end #for all layers
      end #for visData.visNodes != nil
    end #if visData != nil

    ret = ret + "</initialize>\0"
    
    #print out the initialize xml
    #puts ret 
    
    return ret
    
  end
  
  def createStopXML()
    ret="<stop></stop>\0"
  end
  
  def createPauseXML()
    ret="<pause></pause>\0"
  end
  @visDataModel = nil
end
