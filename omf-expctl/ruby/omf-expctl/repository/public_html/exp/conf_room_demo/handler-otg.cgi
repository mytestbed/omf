#!/usr/bin/perl

use CGI;
use CGI::Carp qw(fatalsToBrowser);


my $cgi = CGI->new();

# my $in = $ENV{'QUERY_STRING'};

%params=$cgi->Vars;



#REFRESH RATE FROM FORM
if ($params{"refresh"}){$refresh=$params{"refresh"};} else {$refresh=10;}


#INTERNAL VARIBLES
$errorid=time();
@nodes;
@stats;


#OPENING HEADERS AND HTML TAGS
print $cgi->header(
    -Refresh=>$refresh,
    -Expires=> "Tue, 08 Apr 1997 17:20:00 GMT",
    -Expires=> "0",
    -Pragma=> "no-cache",
    -Cache-Control=> "must-revalidate",
    -Cache-Control=> "max-age=3600",
    -Cache-Control=> "no-cache",
    -type=> "text/html"
    );

print $cgi->start_html(PLOTS);
# print $in;


#DRAW PARAMTERS FROM FORM
if ($params{"host"}){$host=$params{"host"};} else{ $host="idb1";}
if ($params{"gran"}){$gran=$params{"gran"};} else {$gran=100;}
if ($params{"size"}){$size=$params{"size"};} else {$size=350;}
if ($params{"db"}){$db=$params{"db"};} else {BAD("Please enter database name");}

#PARSE KEY-VALUES
foreach $key (keys(%params))
{
  if ($key =~m/node/){unshift(@nodes,$key)}
  if ($key =~m/rssi/){unshift(@stats,1);}
  if ($key =~m/txrate/){unshift(@stats,2);}
  if ($key =~m/throughput/){unshift(@stats,3);}
  if ($key =~m/offeredload/){unshift(@stats,4);}
}


#CHECK FOR NODES AND STATS
if (!(scalar(@nodes) && scalar(@stats))){BAD("Please choose at least one node and one stat");}

#RELATE STAT TO LABELS AND TABLES

%stat_id=(
    "1"=>["RSSI","Card_Units","receiver_otr_receiverport","rssi"],
    "2"=>["Transmit%20Rate","kbps","receiver_otr_receiverport","Xmitrate"],
    "3"=>["Throughput","bytes_per_second","receiver_otr_receiverport","rcvd_pkt_size_sample_sum"],
    "4"=>["Offered%20Load","bytes_per_second","sender_otg_senderport","pkt_size_sample_sum"],
   );


#LAYOUT

print "<TABLE BORDER>\n";


foreach $node (@nodes){
  print "<TR>";
  foreach $stat (@stats){
    print "<TD ALIGN=\"CENTER\"> <B> " . ucfirst($node) . "</B> <BR>";
    print "<IMG SRC=./viewstats.cgi";
    print "?host=" . $host;
    print "&size=" . $size;
    print "&gran=" . $gran;

    print "&db=" .$db;
    print "&label=" . @{$stat_id{$stat}}[0];
    print "&units=" . @{$stat_id{$stat}}[1];
    print "&qstring1=" . "1000000";
    print "&qstring=SELECT%20@{$stat_id{$stat}}[3],timestamp%20from%20@{$stat_id{$stat}}[2]%20where%20node_id=\'" . $node . "\'>\n" ;
    print "</TD>";
  }
  print "</TR>";
}


print $cgi->end_html;

sub BAD
{
  print $errorid . "  " . $_[0] . "<BR>\n" . $cgi->end_html();
  exit(1);
}

#This SQL query was used for the older database schema of value, timestamp
#	print "&qstring=SELECT%20value,timestamp%20from%20metrics_values%20where%20id=" . $stat ."%20and%20node_id=\'" . $node . "\'>\n" ;
