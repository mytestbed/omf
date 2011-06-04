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
	
	$('input').map(function() {
		//alert($(this).attr("cm"));
		if ($(this).attr("cm") == "refresh") this.click();
	})
	
});
