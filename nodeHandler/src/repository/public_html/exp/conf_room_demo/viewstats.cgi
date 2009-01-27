#!/usr/bin/perl

#use lib "/var/web/www/cgi-bin";
#use lib ".";

#use lib "/usr/lib/perl5/auto";
#use lib "/var/web/www/cgi-bin/GD";

use CGI;
use GD::Graph::lines;
#use GD::Graph;
##use GD;
use Mysql;
use Fcntl;

my $cgi = CGI->new();

%params=$cgi->Vars;

#EXPECTED QUERY KEYWORDS: host, user, gran, label, qstring, units, errorid
#MANDATORY QUERY KEYWORDS: db

#Enable auto refresh and disable caching
print $cgi->header(-type=> "image/png");

#FIXED Parameters
$password = "orbit";
$driver   = 'mysql';

#OPEN DEBUG LOG FILE
umask(0000);
sysopen (OUT, "/tmp/viewstats.log", O_WRONLY|O_APPEND|O_CREAT, 0666);

# foreach $key (sort keys(%ENV)) {
#       print OUT "$key = $ENV{$key}\n";
#     }

#EXPECTED PARAMETERS (IF NOT POPULATED, SET TO DEFAULTS)

if ($params{"host"}){$hostname = $params{"host"};} else{ $hostname ="localhost";}
if ($params{"user"}){$user = $params{"user"};} else { $user ="orbit";}
if  ($params{"label"}){$label = $params{"label"};} else {$label=" ";}

#THIS IS BEING DEPRECATED IN LIEU OF AN AUTO SCALAR
#if ($params{"gran"}){$gran=$params{"gran"};} else {$gran=100;}

if ($params{"size"}){$size=$params{"size"};} else {$size=350;}
if ($params{"units"}){$units=$params{"units"};} else {$units=" ";}
if ($params{"errorid"}){$errorid=$params{"errorid"};} else {$errorid = time();}
if ($params{"qstring"}){$sql_query = $params{"qstring"};}
else {$sql_query="SELECT * from otg_sender_otg_senderport";}


# FOR NOW, DEBUGGING / LOGGING
print OUT $errorid . " "  . $sql_query . "\n";


#CHECK FOR MANDATORY PARAMETERS, ELSE DIE
if  ($params{"db"}){$database = $params{"db"};}
else {BAD("NEED DATABASE NAME ");}

print OUT $hostname . " "  . $database . " " . $user . " " . $password . "\n";

#CONNECT TO DATABASE
$dbh = Mysql->connect($hostname, $database, $user, $password) or
BAD("Could not connect to $hostname $database ");

$sth = $dbh->query($sql_query) or BAD("Could not execute query on database");


#SINCE WE ONLY RETRIEVE TWO COLUMNS, THEY ARE PLACE IN ARRAYS
#THE SECOND COLUMN IS USED AS THE LABELS FOR THE X-AXIS


@yvals = $sth->FetchCol(0);
@xvals = $sth->FetchCol(1);

print OUT "Received result from DB\n";

#SCALE X AXIS

$counter = 0;
$start=@xvals[0];

#EXPERIMENTAL CODE, ATTEMPT TO INTELLEGENTLY CHOOSE GRANULARITY
if($#xvals > 30){$gran=($#xvals/5)} else {$gran=2;}

foreach $xval(@xvals)
{
    $xval = ($xval-$start);
    $counter++;
    if ($counter%$gran) {
  $xval = "";
    }

}

#CHECK TO SEE IF ARRAY IS EMPTY, IF EMPTY DRAW VOID IMAGE
$xlen = @xvals;
$ylen = @yvals;

if (!($xlen || $ylen)) {
    $label="NO DATA";
    $units="NO DATA";
    @xvals=(0,1);
    @yvals=(1, 1000000);
}


#USE THE ACQUIRED VALUES TO POPULATE THE PICTURE.
my @data     = ( \@xvals, \@yvals);
print OUT "Before creating graph\n";
my $graph = GD::Graph::lines->new($size,$size);
print OUT "After creating graph\n";
$graph->set( title   => $label,
       y_label => $units);


$graph->set( line_width => 5);
$graph->set( y_tick_number => 5);

#Disable grid, to enable uncomment following line
#$graph->set( long_ticks => true);
$graph->set( tick_length => -4);






#PLOT IMAGE TO FILE
my $image = $graph->plot( \@data ) or
    BAD("Cannot create image");
print $graph->plot(\@data)->png();

#CLOSE LOG FILE
close OUT;

#DUMPS OUTPUTS ERRORS TO FILE AND DIES.
sub BAD {
    print $errorid . " " .$_[0] .  "\n";
    print OUT $errorid . " " .$_[0] .  "\n";
    exit(1);
}



