//package flare.vis.operator.encoder
package omf.vis

{
	import flare.scale.ScaleType;
	import flare.util.palette.Palette;
	import flare.util.palette.SizePalette;
	import flare.vis.data.Data;
	import flare.vis.operator.encoder.Encoder;
	
	
	/**
	 * Encodes a data field into scale values, using a scale transform and a
	 * size palette to determines an item's scale. 
	 */
	public class ScaleEncoder extends Encoder
	{
		private var _palette:SizePalette;
		
		/** @inheritDoc */
		public override function get palette():Palette { return _palette; }
		public override function set palette(p:Palette):void {
			_palette = p as SizePalette;
		}
		/** The palette as a SizePalette instance. */
		public function get sizes():SizePalette { return _palette; }
		
		// --------------------------------------------------------------------
		
		/**
		 * Creates a new SizeEncoder. By default, the scale type is set to
		 * a quantile scale grouped into 5 bins. Adjust the values of the
		 * <code>scale</code> property to change these defaults.
		 * @param source the source property
		 * @param group the data group to process
		 * @param palette the size palette to use. If null, a default size
		 *  palette will be used.
		 */

		public function ScaleEncoder(source:String=null,
      group:String=Data.NODES, target:String="lineColor",
      palette:SizePalette=null, scaleType:String=ScaleType.QUANTILE, numOfBins:int=5)
		{
			super(source, target, group);
			_binding.scaleType = scaleType;
			_binding.bins = numOfBins;
			if (palette) {
				_palette = palette;
			} else {
				_palette = new SizePalette();
				_palette.is2D = (group != Data.EDGES);
			}
		}
		
		/** @inheritDoc */
		protected override function encode(val:Object):*
		{
			return _palette.getSize(_binding.interpolate(val));
		}
		
	} // end of class SizeEncoder
}