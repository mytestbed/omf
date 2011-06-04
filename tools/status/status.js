$(document).ready(function(){
	
	$('input').click(function() {
		//alert("Thanks for visiting!");
		
		var node = $(this).attr("name")
		
		$.ajax({
			type : 'POST',
			url : 'status.php',
			data: {
				node : node,
				action : $(this).attr("cm")
			},
			beforeSend: function(){
				$('#'+node).html("<img src=ajax-loader.gif>");
		    },
		    success: function(status){
				$('#'+node).hide();
				$('#'+node).fadeIn();
		    	$('#'+node).html(status);
		    }
		});

		return false;
	});
	
	$('input').filter(function() {
		//alert($(this).attr("cm"));
		return $(this).attr("cm") == "refresh";
	}).click();
	
	$('input').filter(function() {
		return $(this).attr("map") != "";
	}).click(function() {
		$('#map').html("<img src=../"+$(this).attr("map")+".png>");
	});
	
});
