#!/usr/bin/perl

# http://search.cpan.org/dist/Nmap-Parser/Parser.pm

# Author: Christoph Dwertmann

use Nmap::Parser;
use CGI qw(:standard);

print header();
# auto refresh 5 seconds after script finishes:
# print ("<head><META HTTP-EQUIV='Refresh' CONTENT='5'><title>Status of the NICTA Testbed</title></head>");
print ("<head><title>Status of the NORBIT testbed</title></head>");

print "<body bgcolor=#d0d0d0>
<table><tr><td width=20%></td><td width=60%>
<h3>Status of the NICTA Testbed</h3>
  Please manually reload this page to see the current testbed status. <br><br>
<table border cellpadding=2>";

my $root="http://norbit.npc.nicta.com.au";
my $np = new Nmap::Parser;
my @ips;

my $prefix = "10.0.0.";

for($i = 1; $i <= 38; $i++) {
	push(@ips, "$prefix$i"); 
}

#runs the nmap command with hosts and parses it automagically
$np->parsescan('/usr/bin/nmap','-p 22-23', @ips);

print "Status as of ", $np->get_session()->time_str(), "<br><br>";
# 
# foreach (@ips) {
# 	print "<tr><td>$_</td>";
# 	if ($np->get_host($_)) {
# 		if (($np->get_host($_)->tcp_open_ports)[0] == "22") {
# 			print "<td bgcolor=green align=center>Up</td>\n";
# 		} else {
# 			print "<td bgcolor=yellow align=center>PXE</td>\n";			
# 		}
# 	} else {
# 		print "<td bgcolor=red align=center>Down</td>\n";
# 	}
# 	print "</tr>";
# }

for ($second = 0; $second <= 9; $second++){
	print "<tr>";
	for ($first = 0; $first <= 3; $first++){
		if ($first==0) {
			$nr=$second;
		} else {
			$nr=$first.$second;
		}
		$ip = $prefix.$nr;
		if ($first.$second < 1 || $first.$second > 38){
			print "<td></td>\n";	
			next;
		}
		$color="red";
		if ($np->get_host($ip)) {
			$color="green" if (($np->get_host($ip)->tcp_open_ports)[0] == "22");
			$color="yellow" if (($np->get_host($ip)->tcp_open_ports)[0] == "23");
		}
		if ($color eq "red") {
			system("wget -qO- http://localhost:5053/cmcn/status?domain=norbit\\&hrn=omf.nicta.node".$nr." | grep POWEROFF");
			$color="white" if ($? == 0);
		}
		print "<td bgcolor=$color align=center>$ip</td>\n";
	}
	print "</tr>";
}

print "</table><br>\n";
print "<table border cellpadding=2 width=350px>\n";
print "<tr><td bgcolor=green align=center>Up (SSH login)</td></tr><tr><td bgcolor=yellow align=center>PXE (Telnet login, used during load/save)</td></tr><tr><td bgcolor=red align=center>Down (powered on but no SSH/Telnet)</td></tr><tr><td bgcolor=white align=center>Off (Powered off)</td></tr></table><br>\n";
print "<img src=$root/L3N.png width=800>L3N</img>\n";
print "<img src=$root/L4N.png width=800>L4N</img>\n";
print "<img src=$root/L4S.png width=800>L4S</img>\n";
print "<img src=$root/L5S.png width=800>L5S</img>\n";
print "</body></html>\n";
