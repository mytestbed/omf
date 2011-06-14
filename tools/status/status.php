<?php

$prefix = "omf.nicta.";
$cm_url = "http://localhost:5053/cmc/";
$domain = "norbit";

if (!empty($_POST['node'])) {
	$node = ereg_replace("[^a-z0-9]", "", $_POST['node']);
	$action = ereg_replace("[^a-zA-Z]", "", $_POST['action']);
	
	//sleep ( rand ( 1, 3));
	if ($action != "refresh") {
		$url = $cm_url.$action ."?domain=".$domain."&hrn=".$prefix.$node;
		file_get_contents($url);
		sleep(1);
	}
	exec('nmap 10.0.0.'.ereg_replace("[^0-9]", "", $node).' -p 22-23', $output);
	
	if (in_array("22/tcp open   ssh",$output)) {
		echo "<SPAN style='BACKGROUND-COLOR: lightgreen'>&nbsp;Powered On, SSH&nbsp;</SPAN>";
	} else if (in_array("23/tcp open   telnet",$output)) {
		echo "<SPAN style='BACKGROUND-COLOR: yellow'>&nbsp;Powered On, Telnet (PXE)&nbsp;</SPAN>";
	} else {
		$url = $cm_url."status?domain=".$domain."&hrn=".$prefix.$node;
		if (strstr(file_get_contents($url),"POWERON")) {
			echo "<SPAN style='BACKGROUND-COLOR: gold'>&nbsp;Powered On, no Telnet/SSH&nbsp;</SPAN>";
		} else {
			$url = $cm_url."acstatus?domain=".$domain."&hrn=".$prefix.$node;
			if (strstr(file_get_contents($url),"POWERON")) {
				echo "<SPAN style='BACKGROUND-COLOR: orangered'>&nbsp;Powered Off&nbsp;</SPAN>";
			} else {
				echo "<SPAN style='BACKGROUND-COLOR: crimson'>&nbsp;No AC Power&nbsp;</SPAN>";
			}
		}
	}
	exit;
}
?>

<!DOCTYPE html>
<html>
<head>
  <title>NORBIT Testbed Status</title>
  <link href="scaffold.css" media="screen" rel="stylesheet" type="text/css" />
  <link href="status.css" media="screen" rel="stylesheet" type="text/css" />
  <script src="jquery.js"></script>
  <script src="status.js"></script>
</head>
<body>

<center>
<h1>NORBIT Testbed Status</h1>

<table>
  <tr>
    <th>Node</th>
    <th>Status</th>
  </tr>

<?php 

$nodes = array();
for ($i = 1; $i <= 38; $i++) {
	array_push($nodes, "node".$i);
}

$oddrow = true;

foreach($nodes as $node) {
	if ($oddrow) {
		echo "<tr class='node odd'>";
	} else {
		echo "<tr class='node even'>";
	}
	$oddrow=!$oddrow;
?>
  <td><?= $prefix.$node ?></td>
	<td align="center"><div id="<?= $node ?>"><img src=ajax-loader.gif></div></td>
	<td><form method="post"><input type="submit" name="<?= $node ?>" value="Refresh" cm="refresh"/></form></td>
	<td><form method="post"><input type="submit" name="<?= $node ?>" value="Reboot" cm="reboot"/></form></td>
	<td><form method="post"><input type="submit" name="<?= $node ?>" value="Reset" cm="reset"/></form></td>
	<td><form method="post"><input type="submit" name="<?= $node ?>" value="Power On" cm="on"/></form></td>
	<td><form method="post"><input type="submit" name="<?= $node ?>" value="Soft Power Off" cm="offSoft"/></form></td>
	<td><form method="post"><input type="submit" name="<?= $node ?>" value="Hard Power Off" cm="offHard"/></form></td>		
</tr>
<?php	
}
?>
</table>
<h2>Maps</h2>
<form>
  <input type="button" value="L3N Map" map="L3N"/>
  <input type="button" value="L4N Map" map="L4N"/>
  <input type="button" value="L4S Map" map="L4S"/>
  <input type="button" value="L5S Map" map="L5S"/>
</form>

<div id="map"></div>
</center>
</body>
</html>



