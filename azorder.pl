#!/usr/bin/perl

# *********************************************************************
#                         Copyright Notice.
# *********************************************************************
#
# Copyright (C) 2011 Charles Ledvina.
#
# This file is part of Amazon to MARC Converter.
#
# Amazon to MARC Converter is free software: you can redistribute it
# and/or modify it under the terms of the GNU Affero General Public
# License as published by the Free Software Foundation, either version
# 3 of the License, or (at your option) any later version.
#
# Amazon to MARC Converter is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public
# License along with Amazon to MARC Converter.  If not, see
# <http://www.gnu.org/licenses/>.
#
# Charles Ledvina
# cledvina@chopac.org

open INIFILE, 'az2marc.ini';
while (<INIFILE>) {
	chomp;
	my ($k, $v) = split / = |=/;
	$INI{$k} = $v
}

use LWP::Simple;

require 'clweb.pm';

$ctime = time;
$qs = $ENV{QUERY_STRING} || <STDIN>;
%q = qstring($qs);
$q{CT} ||= 'com';

&content;

############################################ Scripts and CSS ##############################################################################
print <<"__END__SCRIPT__";
<style>
	body { font-family: arial; font-size: 12 }
	a:link { color: 006699; text-decoration: none }
	a:visited { color: 006699; text-decoration: none }
	.search { background-color: beige; padding: 25px; width: 90%; font-size: 14; text-align: center; border: solid; border-width: 1px }
	.rec { background-color: eeeeee; color: 000000; padding: 25px; width: 90%; border: solid; border-width: 1px; margin-top: 5px }
	.rec0 { background-color: eeeeee; color: 000000; padding: 25px; width: 90%; border: solid; border-width: 1px; margin-top: 5px }
	.rec1 { background-color: 99FFAA; color: 000000; padding: 25px; width: 90%; border: solid; border-width: 1px; margin-top: 5px }
	.rec2 { background-color: pink; color: 000000; padding: 25px; width: 90%; border: solid; border-width: 1px; margin-top: 5px }
	.statbar { background-color: ffffff; color: 999999; padding: 0px; width: 50%; font-size: 12}
	.bar { background-color: ffffff; color: 999999; padding: 0px; width: 90%; font-size: 10}
	.button:hover { background-color: dddddd }
	.button { margin: 1px; border: outset; border-width: 2px; background-color: eeeeee; padding: 2px }
	.mb { font-size: 10px; margin: 1px; border: outset; border-width: 2px; background-color: eeeeee; padding: 1px }
	.mf { font-size: 10px; border: solid; border-width: 1px; border-color: 006699; text-align: center; padding: 10px; background-color: dfefff }
	.status { border: solid; border-width: 1px; width: 30%; color: black; background-color: dfefff; margin-top: 40px; padding: 10px }
	.warn { color: red; font-weight: bold }
	.ti { font-size: 16px }
	textarea { height: 20px }
	img { border-width: 0px }
	.list { border-bottom: dashed; border-width: 1px; width: 90%; height: 20%; font-family: arial; font-size: 14 }
	.til { padding: 15px; position: absolute; display: none; background-color: BBFFCC; opacity: .9; border: solid; border-width: 1px }
	.sv { padding: 15px; position: fixed; left: 300px; top: 300px; display: none; background-color: BBFFCC; opacity: .9; border: solid; border-width: 1px }
	.close { color: 999999; border: solid; border-width: 1px; padding: 5px}
	

</style>
<script>
	var hR;
	if (window.XMLHttpRequest) {
		hR = new XMLHttpRequest();
	}
	else {
		hR = new ActiveXObject("Msxml2.XMLHTTP");
	}

	function cook() {
		if (document.cookie == "") {
			document.cookie = "$ctime-$$"
		}
	}
	function viewButton() {
		if (document.sform.isbn.value.match(/[a-wyz]/i)) {
			document.getElementById("default").value = "Books";
			document.getElementById("other").style.visibility = "visible"
		}
		else {
			document.getElementById("default").value = "Blended";
			document.getElementById("other").style.visibility = "hidden"
		}

	}

	function ly(addr) {
        	hR.onreadystatechange = function() {
			var s = document.getElementById('tlist');
			s.style.display = "block";
			if (hR.readyState == 4) {
				s.innerHTML = hR.responseText
			}
		}
        	hR.open('GET', addr, true);
        	hR.send(null);
	}

	function sv(asin) {
        	hR.onreadystatechange = function() {
			var s = document.getElementById('sv');
			s.style.display = "block";
			if (hR.readyState == 4) {
				s.innerHTML = hR.responseText;
				window.setTimeout('lo("sv")', 2000)
			}
		}
        	hR.open('GET','az2marc.pl?ct=$q{CT}&rda=$q{RDA}&kw=' + asin + '&qx=2' , true);
        	hR.send(null);

	}
	function vw(asin) {
		location.href = 'az2marc.pl?ct=$q{CT}&rda=$q{RDA}&kw=' + asin
	}
	function ex(asin) {
		location.href = 'az2marc.pl?ct=$q{CT}&rda=$q{RDA}&kw=' + asin + '&qx=1'
	}
	function buy(asin) {
		location.href = 'http://www.amazon.$q{CT}/exec/obidos/ASIN/' + asin
	}

//buy-from-tan.gif
	function lo(myDiv) {
		var s = document.getElementById(myDiv);
		s.style.display="none";
	}
</script>
<body onLoad='viewButton(); document.sform.isbn.select(); cook()'>
__END__SCRIPT__

############################################ Program Control ###########################################################################
if ($q{ISBN}) { &amazon }
else { &sform }

############################################ Search Form ###############################################################################
sub sform {
	$CSL{$q{CT}} = 'selected';
	print "<center><table class='search'><tr><td colspan='2'><form name='sform' action='$ENV{SCRIPT_NAME}'>";
	print "Enter Keywords, ISBN, EAN or UPC: ";
	print " <input type='text' name='isbn' value='$q{ISBN}' onKeyUp='viewButton()'>";
	print "<span id='go' style='display:none'> <input type='submit' id='default' class='button' name='type' value='Blended'></span>";
	print "<span id='other' style='visibility:hidden'> <input type='submit' class='button' name='type' value='Books'>";
	print " <input type='submit' class='button' name='type' value='Video'>";
	print " <input type='submit' class='button' name='type' value='Music'>";
	print " <input type='submit' class='button' name='type' value='VideoGames'>";
	print " <input type='submit' class='button' name='type' value='KindleStore'></span>";
### onMouseOver='ly(\"$ENV{SCRIPT_NAME}?lv=1\")' onMouseOut='lo(\"tlist\")' insert in to export button ###
	print "<tr><td align='left'><input type='button' class='mb' value='Export Saved Records' onClick='location.href=\"az2marc.pl?save=batch\"'>";
	if ($q{RDA}) { $rchk = ' checked' }
	print "<td align='right'><input type='checkbox' name='rda' value='1'$rchk>RDA Format | Choose a Country: <select name='ct'>";
	print "<option value='com' $CSL{com}>United States";
	print "<option value='ca' $CSL{ca}>Canada";
	print "<option value='fr' $CSL{fr}>France";
	print "<option value='de' $CSL{de}>Germany";
	print "<option value='co.uk' $CSL{'co.uk'}>United Kingdom";
	print "</select>";
	print "<div class='til' id='tlist'></div>";
	print "</table></form></center>"
}

########################################################## Display a single brief record ##############################################################
sub display {
	print "<table class='list'>";
	print "<tr><td valign='center' align='center' width='20%'><img src='http://images.amazon.com/images/P/$AZ{asin}.01._SL110_SCTZZZZZZZ_.jpg'>";
	print "<td valign='top'><a class='ti' href='javascript:buy(\"$AZ{asin}\")'><b>$AZ{title}</b></a>";
	print "<br>$AZ{publisher}, $AZ{date}.<br>$AZ{price}<br><img src='http://chopac.org/images/buy-from-tan.gif' onClick='buy(\"$AZ{asin}\")'>";
	print "<p><a href='azrev.pl?q=$AZ{asin}'>Customer Reviews</a>";
	print "<td align='right' width='20%'>";
	print "<div class='mf'>Marc Functions<br>";
	print "<input type='button' class='mb' value='View' onClick='vw(\"$AZ{asin}\")'>";
	print "<input type='button' class='mb' value='Export' onClick='ex(\"$AZ{asin}\")'>";
	print "<input type='button' class='mb' value='Save' onClick='sv(\"$AZ{asin}\")'>";
	print "</div></table>";
	print "<div id='sv' class='sv'></div>";

}

####################################################### Pages through the results ######################################################################
sub pager {
	my $np = $Page + 1;
	my $pp = $Page - 1;
	$q{ISBN} =~ s/ +/+/g;
	print "<td align='right'>";
	if ($Page > 1) { print " <a href='$ENV{SCRIPT_NAME}?ct=$q{CT}&isbn=$q{ISBN}&type=$q{TYPE}&pg=$pp'>&lt Prev</a>" }
	else { print "&lt Prev" }
	if ($Page < $Pages) { print " <a href='$ENV{SCRIPT_NAME}?ct=$q{CT}&isbn=$q{ISBN}&type=$q{TYPE}&pg=$np'>Next &gt</a>" }
	else { print " Next &gt" }
	print "</center></table>";
}

##################################################### Connects to Amazon and searches and gets results #################################################
sub amazon {
	&sform;
	$q{TYPE} ||= 'Blended';
	if ($q{TYPE} eq 'Blended' && $q{ISBN} =~ /[a-wyz]/) { $q{TYPE} = "Books" }

	$q{PG} ||= 1;

##### This section was added to accomadate the new signed request requirements ################################################

	use RequestSignatureHelper;

	my $endPoint = "ecs.amazonaws.$q{CT}";
	my $resGroup = "ItemAttributes,Tracks";

	my $helper = new RequestSignatureHelper (
		+RequestSignatureHelper::kAWSAccessKeyId => $INI{accesskey},
		+RequestSignatureHelper::kAWSSecretKey => $INI{secretkey},
		+RequestSignatureHelper::kEndPoint => $endPoint,
	);

	my $request = {
    		Service => 'AWSECommerceService',
    		AssociateTag => $INI{associate},
    		Operation => 'ItemSearch',
		Keywords => $q{ISBN},
		ItemPage => $q{PG},
		SearchIndex => $q{TYPE},
    		Version => '2009-03-31',
    		ResponseGroup => 'ItemAttributes',
	};
	my $signedRequest = $helper->sign($request);
	my $queryString = $helper->canonicalize($signedRequest);
	my $ad = "http://" . $endPoint . "/onca/xml?" . $queryString;

################################################################################################################################

	my $xml = get($ad);
	if ($xml =~ s/^(.+?)(<item>)/$2/i) {
		$leader = $1;
		if ($leader =~ /<TotalResults>(.+?)<\/TotalResults>/i) { $Tot = $1 }
		if ($leader =~ /<TotalPages>(.+?)<\/TotalPages>/i) { $Pages = $1 }
		if ($leader =~ /<ItemPage>(.+?)<\/ItemPage>/i) { $Page = $1 }
		print "<center><table class='bar'><tr><td>$Tot Records Found (Page $Page of $Pages)";
		&pager;
	}
	else { 
		print "<center><table class='status'><tr><td>No Records Found!<br>";
		exit;
	}
   while ($xml =~ s/<item>(.+?)<\/item>//i) {
	my $x = $1;
	%AZ = ();
	if ($x =~ /<asin>(.+?)<\/asin>/i) {
		$AZ{asin} = $1
		}
	while ($x =~ s/<isbn>(.+?)<\/isbn>//i) {
		$AZ{isbn} = $1
		}
	if ($x =~ /<listprice>.+?<formattedprice>(.+?)<\/formattedprice>/i) {
		$AZ{price} = $1
		}
	if ($x =~ /<author>(.+?)<\/author>/i) {
		$AZ{author} = $1
		}
	if ($x =~ /<artist>(.+?)<\/artist>/i) {
		$AZ{author} = $1
		}
	if ($x =~ /<title>(.+?)<\/title>/i) {
		$AZ{title} = $1;
		$AZ{title} .= " / by $AZ{author}" if $AZ{author};
		}
	if ($x =~ /<publisher>(.+?)<\/publisher>/i) {
		$AZ{publisher} = $1;
	}
	if ($x =~ /<releasedate>(.+?)<\/releasedate>/i) {
		$AZ{date} = $1;
		$AZ{date} =~ s/^(....).+/$1/;
	}
	elsif ($x =~ /<publicationdate>(.+?)<\/publicationdate>/i) {
		$AZ{date} = $1;
		$AZ{date} =~ s/^(....).+/$1/;
	}
	&display;
   }
	print "<center><table class='bar'><tr><td>$Tot Records Found (Page $Page of $Pages)";
	&pager
}
