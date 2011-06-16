$(window).load(function(){

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
	
	// click all refresh buttons after loading
	$('input').filter(function() {
		//alert($(this).attr("cm"));
		return $(this).attr("cm") == "refresh";
	}).click();
	
	// click all offsoft buttons when the alloffsoft button is pressed
	$('input').filter(function() {
		return $(this).attr("all") == "softoff";
	}).click(function() {
		$('input').filter(function() {
			return $(this).attr("cm") == "offSoft";
		}).click();
	});

	// click all on buttons when the allon button is pressed
	$('input').filter(function() {
		return $(this).attr("all") == "on";
	}).click(function() {
		$('input').filter(function() {
			return $(this).attr("cm") == "on";
		}).click();
	});

	// map buttons (match "map" class)
	$(".map").click(function() {
		$('#map').html("<img src=../"+$(this).attr("map")+".png>");
		$('html, body').animate({scrollTop: $(document).height()}, 1);
	});

});
