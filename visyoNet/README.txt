In this document, we describe how to use visualization package for system administrator, users who run visualization clients to observe their experiment results and for developers for debugging and expanding the functionalities.


1.1	For system administrator

The main purpose for system administrator to is to start the service at the server side.

The visualization service can be started at the server side from ~/visyonetcode/ServiceInterface/

Step 1. Configuration files

	cd <yourPath>/visyonetcode/Config/
	
Open the configuration files db.xml and visyonet.xml :
§	db.xml: system administrator needs to specify the database connections, <hostname, username, password, databaseName>
§	visyonet.xml: 
o	change the Config/visyonet.xml file to set HTTPDocRoot to <yourPath>/visyonetcode/FLASHClient/visyonet
o	More important, specify the port number you want to provide HTTPServer connection and updateData connection. Please make sure the port number is not in use with other service. 

Step 2. Start the service
§	cd <yourpath>/visyonetcode/ServiceInterface/
§	ruby runserver.rb

Note: if end-users complains the “unsuccessful connection to servers”, please check:
§	Firewall settings
§	Consistent port settings between client and server

1.2	For user

Use default configurations:
§	Open browser and type the http server name and port, for example, http://external2.orbit-lab.org:80/
§	This will lead you to the entry page
§	Please click “Enter” 
§	In the second page, give you the chance to upload configuration files. Ignore it and go to next
§	The visualization page should be shown. If everything is fine, the bottom part of the page will tell you “connection successfully”
§	Buttons
o	Click “start” button to illustrate the experiment results
o	Click “pause” button to pause the collection of results
o	Click “step+” to illustrate the results step by step forward
o	Click “step-“ to illustrate the results step by step backward
o	Click “stop” to stop the display of the results. Your browser is still connected to the server, and you can restart by click “start” again
o	After you click “pause” or “stop”, you also have the chance to upload your own configuration files (by go back to the previous page) and setup new “averaging intervals”.
§	Click on the nodes and links, you will see a popup windows, which give the current status of node and link.

Use own configuration files:
§	When you use configuration files, please make sure that it is the same format as the default one;
§	For user, you can change the queries by modifying db.xml
§	You can change shape and color from VisMapping.xml
