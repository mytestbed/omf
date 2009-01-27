class MovieClipWithID extends MovieClip {

	public function setID(newID:String) {

		this._id = newID;

		//trace("ID is set to: " + this._id);

	}

		

    public function onPress() {

        trace("Shape id: " + this._id + " was clicked.");
		fscommand("shapeClicked", "Shape id: " + this._id + " was clicked.");
    }

		

	var _id:String = "";

}



