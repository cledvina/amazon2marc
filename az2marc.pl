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
# 5 Whaler Court
# Third Lake, IL 60030-2620
# USA
# http://www.libcat.org
# blp1569@gmail.com

# binmode STDOUT, ":utf8";

open INIFILE, 'az2marc.ini';
while (<INIFILE>) {
	chomp;
	my ($k, $v) = split / = |=/;
	$INI{$k} = $v
}


my $tmp = $INI{tmp};  # Temp file location for batch export

use LWP::Simple;

require 'clweb.pm';
require 'clmarc.pm';

$eqs = $ENV{QUERY_STRING} || <STDIN>;
%q = qstring($eqs);
@cooks = split /;/, $ENV{HTTP_COOKIE};
foreach (@cooks) {
	my ($k, $v) = split /=/;
	$COOK{$k} = $v
}
unless ($q{SAVE} || $q{QX} || $q{BATCH}) {
	print "Content-type: text/html; charset=utf-8\n\n";
	print "<title>Amazon to Marc Converter</title>";
	unless ($COOK{azmarc}) {
		my $sid = time;
		$sid .= "-$$";
		print "<script>document.cookie='azmarc=$sid'</script>";
	}

################# CSS and JavaScripts ##########################################
        print <<"__END__STYLE__";
<style>
	body, .dtxt, .lowcontrol { font-family: helvetica; font-size: 14px }
	ul { font-family: helvetica; text-align: left}
	.search { margin: 25px; padding: 20px; border: solid; border-width: 1px; background-color: beige }
	a:link, a:visited { text-decoration: none }
	.nots { font-size: 14px }
	textarea { font-family: courier; font-size: 14px; background-color: beige; width: 800; height: 600px; border: dotted; border-width: 1px }
	.button:hover { background-color: dddddd }
	.button { margin: 1px; border: outset; border-width: 2px; background-color: eeeeee; padding: 2px }
	.name { font-size: 14px }
	.sbox { font-family: arial; width: 100px }
	.st { font-size: 14px }
	.sb { border-width: 1px; background-color: eeeeee }
	.cd { display: none }
	.s { text-align: left }
	.n { cursor: pointer; color: blue }
	li.n:hover { background-color: dddddd }
        .new { background-color: green; padding: 2px; color: white }
        .footer { border: dotted; border-width: 1px; padding: 10px; background-color: eeeeee; text-align: center }
</style>
<script src="http://www.google-analytics.com/urchin.js" type="text/javascript">
</script>
<script type="text/javascript">
	_uacct = '$INI{analytics}';
	urchinTracker();
</script>
__END__STYLE__
}

################## Program control ######################

if ($q{SAVE}) { &save }
elsif ($q{KW}) { &parse }
elsif ($q{BATCH}) { &batch }
elsif ($q{EMPTY}) { &empty }
elsif ($q{NAMES}) { &names }
elsif ($q{CLASS}) { &classify }
else { &menu }

################## ASIN search menu (if not using azorder.pl) #####################################
sub menu {
	&checkbatch if $COOK{azmarc};
	print "<center><table class='search'><form action='$ENV{SCRIPT_NAME}'>";
	print "<tr><td>Enter ASIN: <input type='text' name='kw'>";
	print " <input class='button' type='submit' value='Go'><br><a href='azorder.pl'><font size='-2'>I don't know the ASIN...</font></a>";
	#print "<tr class='nots'><td><input type='checkbox' value='1' name='lc'> Do NOT Convert to Lowercase";
	print "<tr class='nots'><td><input type='checkbox' value='1' name='rda'> RDA Format";
	#print "<tr class='nots'><td><input type='checkbox' value='1' name='ed'> Do NOT Use Editorial Review as Summary";
	print "<table><tr><td><tr class='nots'><td>Choose a Country:<td><select name='ct' class='sbox'>";
	print "<option value='com'>United States";
	print "<option value='ca'>Canada";
	print "<option value='fr'>France";
	print "<option value='de'>Germany";
	print "<option value='co.jp'>Japan";
	print "<option value='co.uk'>United Kingdom";
	print "<option value='cn'>China";
	print "</select>";
	print "<tr class='nots'><td>Text Conversion:<td><select name='lc' class='sbox'>";
	print "<option value='0'>Lower Case";
	print "<option value='1'>No Conversion";
	print "<option value='2'>Upper Case Title";
	print "</select></table>";
	print "<tr class='nots'><td><input type='checkbox' value='1' name='su'> Do NOT Include Subject Headings";

	print "<tr><td><input class='button' type='submit' name='save' value='$svalue'>" if $svalue;
        print "</form></table></center>";
	&footer
}

######################## Footer contains links to Greasemonkey and Firefox Extensions ############################################
sub footer {
	print "<div class='footer'>";
	print "<br><a href='mailto://cledvina\@chopac.org'>Contact</a>";
        print "</div>";
}

######################## Check and count titles in the batch file ###############################
sub checkbatch {
	if (open BF, "$tmp/$COOK{azmarc}.az") {
		$/ = "\t\n";
		my @a = <BF>; 
		$bai = @a;
		my $s = '';
		if ($bai > 1) { $s = 's' }
		$svalue = "Export Batch ($bai record$s)";
		$/ = "\n"
	}
}

###################### The guts (get and process XML data from amazon.com) ########################
sub parse {
	&checkbatch;
	$svalue ||= "Export";

	$q{KW} =~ s/\W//g;
	if ($q{KW} =~ s/^978(.........)./$1/) {
		my $i = 1;
		foreach (split //, $q{KW}) {
			$chkdig += $_ * $i;
			$i++
		}
		$chkdig = $chkdig%11;
		$chkdig = 'X' if $chkdig == 10;
		$q{KW} .= $chkdig;
	}
	$q{CT} ||= "com";
	%lang = ('com','eng','ca','eng','co.uk','eng','fr','fre','de','ger','co.jp','jpn','cn','chi');

##### This section was added to accommodate the new signed request requirements ################################################

	use RequestSignatureHelper;

	my $endPoint = "ecs.amazonaws.$q{CT}";
	my $resGroup = "ItemAttributes,Tracks,Large";
	#$resGroup .= ",Subjects" unless $q{SU};
	$resGroup .= ",EditorialReview" unless $q{ED};

	my $helper = new RequestSignatureHelper (
		+RequestSignatureHelper::kAWSAccessKeyId => $INI{accesskey},
		+RequestSignatureHelper::kAWSSecretKey => $INI{secretkey},
		+RequestSignatureHelper::kEndPoint => $endPoint,
	);

	my $request = {
    		Service => 'AWSECommerceService',
    		AssociateTag => $INI{associate},
    		Operation => 'ItemLookup',
    		Version => '2009-03-31',
    		ItemId => $q{KW},
    		ResponseGroup => $resGroup,
	};
	my $signedRequest = $helper->sign($request);
	my $queryString = $helper->canonicalize($signedRequest);
	my $ad = "http://" . $endPoint . "/onca/xml?" . $queryString;

################################################################################################################################
	
	%types = ('Book', 'a', 'DVD', 'g', 'Video', 'g', 'Classical', 'j', 'Music', 'j', 'Software', 'm', 'Video Games', 'm', 'eBooks', 'm');
	%rsix = ('Music','performed music |b prm', 'Classical','performed music |b prm', 'DVD','two-dimensional moving image |b tdi', 'Video','two-dimensional moving image |b tdi', 'AudBook', 'spoken word |b spw', 'Book', 'text |b txt', 'Video Games', 'computer program |b cop', 'eBooks', 'computer dataset |b cod');
	%rseven = ('i', 'audio |b s', 'j','audio |b s', 'g', 'video |b v', 'm', 'computer |b c', 'a', 'unmediated |b n');
	%reight = ('Music', 'audio disc |b sd', 'DVD', 'video disc |b vd', 'AudBook', 'audio disc |b sd', 'Video', 'videocassette |b vf', 'eBooks', 'online resource |b cr', 'Video Games', 'computer chip cartridge |b cb', 'Book', 'volume |b nc');

################### Create 005 ###########################
	@cd = localtime(time);
	$cd[5] =~ s/^.//;
	$cd[4] += 1;
	$cd[4] = "0$cd[4]" if length($cd[4]) == 1;
	$cd[3] = "0$cd[3]" if length($cd[3]) == 1;
	$cdate = "$cd[5]$cd[4]$cd[3]";

	%hhh = ('a', '', 'i', ' |h [sound recording]', 'j', ' |h [sound recording]', 'g', ' |h [videorecording]', 'm', ' |h [electronic resource]');
	$x = get($ad);

	$x =~ s/\xC3(.)/chr(ord($1)+64)/ge;
	$x =~ s/.+<item>(.+?)<\/item>.+/$1/i;

################# Lets look at all of the data elements and assign them to a MARC field #################################################3	
	if ($x =~ /<publicationdate>(.+?)<\/publicationdate>/i) {
		$pdate = $1;
		$pdate =~ s/^(....).+/$1/
		}
	elsif ($x =~ /<releasedate>(.+?)<\/releasedate>/i) {
		$pdate = $1;
		$pdate =~ s/^(....).+/$1/
		}
	while ($x =~ s/<productgroup>(.+?)<\/productgroup>//i) {
		$product = $1;
		$mtype = $types{$1};
		}
	while ($x =~ s/<format>(.+?)<\/format>//i) {
		push @{ $mrc{500} }, "   $1";
		if ($1 =~ /aud.+book/i) { $mtype = 'i' }
		elsif ($1 =~ /larg.+rint/i) { $lpflag = 'd' }
	}
	if ($mtype eq 'a' &&  $x =~ /<binding>audio cd<\/binding>/i) { $mtype = 'i' }
	if ($q{RDA}) {
		$mrc{'040'}[0] = "   |e rda";
		if ($mtype eq 'i') { $product = 'AudBook' }
		$mrc{336}[0] = "   $rsix{$product} |2 rdacontent";
		$mrc{337}[0] = "   $rseven{$mtype} |2 rdamedia";
		$mrc{338}[0] = "   $reight{$product} |2 rdacarrier"
	}	
	if ($mtype eq 'g') {
		my $fmt = join ", ", @{ $mrc{500} };
		$fmt =~ s/ +/ /g;
		@{ $mrc{538} } = ("  $fmt");
		@{ $mrc{500} } = ()
	}
	if ($x =~ /<asin>(.+?)<\/asin>/i) {
		push @{ $mrc{'001'}}, "ASIN$1";
		$asin = $1
		}
	while ($x =~ s/<isbn>(.+?)<\/isbn>//i) {
		$world = $1;
		push @{ $mrc{'020'} }, "   $1";
		}

	if ($mtype eq 'a') {
		while ($x =~ s/<ean>(.+?)<\/ean>//i) {
			push @{ $mrc{'020'}}, "   $1"
			}
		}
	else {
		while ($x =~ s/<upc>(.+?)<\/upc>//i) {
			$world = $1;
			push @{ $mrc{'024'}}, "1  $1"
			}
		}
	while ($x =~ s/<binding>(.+?)<\/binding>//i) {
	        $ibind = lc $1;
		foreach (@{ $mrc{'020'} }) {
	            $_ = "$_ ($ibind)"
                }
	}

	if ($x =~ /<listprice>.+?<formattedprice>(.+?)<\/formattedprice>/i) {
		my $spc = " ";
		$spc = "   " unless $mrc{'020'}[0];
		$mrc{'020'}[0] .= "$spc|c $1";
		}

	if ($x =~ /<deweydecimalnumber>(.+?)<\/deweydecimalnumber>/i) {
		$mrc{'082'}[0] = "04 $1";
		}
	while ($x =~ s/<author>(.+?)<\/author>//i) {
		auflip($1);
		}
	while ($x =~ s/<artist>(.+?)<\/artist>//i) {
		auflip($1);
		}
	while ($x =~ s/<actor>(.+?)<\/actor>//i) {
		auflip($1,'700');
		$mrc{511}[0] = "1  Starring " unless $mrc{511}[0];
		$mrc{511}[0] .= "$1, ";
		}
	$mrc{511}[0] =~ s/\W+?$/./ if $mrc{511}[0];
	while ($x =~ s/<creator(.+?)>(.+?)<\/creator>//i) {
		my $cname = $2;
		if ($1 =~ /illus/i) { $illflag = 1 }
		auflip($cname,'700');
		}
	if ($x =~ /<tracks>(.+?)<\/tracks>/i) {
		my $trx = $1;
		while ($trx =~ s/<track.+?>(.+?)<\/track>//i) {
			$dat = lup($1);
			push @tracks, "|t $dat"
			}
		$mrc{'505'}[0] = "0  " . join " -- ", @tracks
		}
	if ($x =~ /<title>(.+?)<\/title>/i) {
		my $ti = $1;
		if ($ti =~ s/ \((.+)\)//) { $se = $1 }
		$ti = lup($ti) unless $q{RDA};
		my $ia = 0;
		if ($statement) { $ia = 1 }
		my $ib = nofile($ti);
		my @tp = split / : |: /, $ti;
		$tp[0] .= "$hhh{$mtype}" unless $q{RDA};
		$ti = join " : |b ", @tp;
		$ti =~ s/,{0,1} (book |vol\. |volume |no\. |#)(\d+)/. |n \u$1 $2/i;
		$mrc{245}[0] = "$ia$ib $ti";
                $statement =~ s/, $//;
		$mrc{245}[0] .= " / |c $statement" if $statement;
		if ($se) {
			$se = lup($se);
			my $ind = nofile($se);
			$se =~ s/,{0,1} (book |vol\. |volume |no\. |#)(\d+)/ ; |v \u$1 $2/i;
			$mrc{830}[0] = " $ind $se";
			$mrc{490}[0] = "1  $se"
			}
		}
	if ($x =~ /<edition>(.+?)<\/edition>/i) {
		my $n = $1;
		if ($n =~ /edition|ed/i) { $mrc{250}[0] = "   $n" }
		else {
			if ($n =~ s/^([2-9]1|1)$/$1st/) {}
			elsif ($n =~ s/^([2-9]2|2)$/$1nd/) {}
			elsif ($n =~ s/^([2-9]3|3)$/$1rd/) {}
			elsif ($n =~ s/^([0-9]+)$/$1th/) {}
			$mrc{250}[0] = "   $n ed" unless $n =~ /edition|ed/i;
		}
	}
	if ($x =~ /<publisher>(.+?)<\/publisher>/i) {
		$publ = $1;
		$mrc{260}[0] = "   [S.l.] : |b $publ, |c $pdate";
	}
	if ($x =~ /<mpn>(.+?)<\/mpn>/i) {
		my $n = $1;
		my $i = '42';
		$i = '32' if $mtype =~ /[ij]/;
		push @{ $mrc{'028'}}, "$i $n |b $publ";
		}
	if ($x =~ /<runningtim.+?>(.+?)<\/runningtime>/i) {
		$runtime = " ($1 min.)";
	}
	if ($mtype eq 'a' or $product =~ /ebooks/i) {
		if ($x =~ /<numberofpages>(.+?)<\/numberofpages>/i) {
			$mrc{300}[0] = "$1 p.";
			$mrc{300}[0] .= " (large print)" if $lpflag;
		}
		else { $mrc{300}[0] = "1 v. (unpaged)" }
		if ($illflag) { $mrc{300}[0] .= " : |b col. ill." }
		if ($x =~ /<packagedimensions>.+?<length.+?>(.+?)<\/length>/i) {
			$cm = int($1 * .0254) + 1;
			$mrc{300}[0] .= " ; |c $cm cm";
		}
		if ($product =~ /ebooks/i) { $mrc{300}[0] = "1 online resource ($mrc{300}[0])" }
		$mrc{300}[0] = "   $mrc{300}[0]"
	}
	elsif ($mtype eq 'j') {
		if ($x =~ /<numberofdiscs>(.+?)<\/numberofdiscs>/i) {
			my $disc = "disc";
			$disc = "discs" if $1 > 1;
			$mrc{300}[0] = "   $1 sound $disc : |b digital ; |c 4 3/4 in";
		}
	}
	elsif ($mtype eq 'm') {
		if ($x =~ /<numberofdiscs>(.+?)<\/numberofdiscs>/i) {
			my $disc = "CD-ROM";
			$disc = "CD-ROMs" if $1 > 1;
			$mrc{300}[0] = "   $1 $disc : |b digital ; |c 4 3/4 in";
		}
	}
	elsif ($mtype eq 'i') {
		if ($x =~ /<numberofitems>(.+?)<\/numberofitems>/i) {
			my $disc = "disc";
			$disc = "discs" if $1 > 1;
			$mrc{300}[0] = "   $1 sound $disc : |b digital ; |c 4 3/4 in";
		}
	}
	elsif ($product eq 'DVD') {
		my $count = 1;
		my $disc = "disc";
		if ($x =~ /<numberofdiscs>(.+?)<\/numberofdiscs>/i) {
			$count = $1;
			$disc = "discs" if $1 > 1
		}
		$mrc{300}[0] = "   $count video$disc$runtime : |b sd., col ; |c 4 3/4 in";
	}
	elsif ($product eq 'Video') {
		my $count = 1;
		my $disc = "cassette";
		if ($x =~ /<numberofitems>(.+?)<\/numberofitems>/i) {
			$count = $1;
			$disc = "cassettes" if $1 > 1
		}
		$mrc{300}[0] = "   $count video$disc$runtime : |b sd., col ; |c 1/2 in";
	}

	while ($x =~ s/<similarproduct>(.+?)<\/similarproduct>//i) {
		my $sp = $1;
		$sp =~ /<title>(.+?)<\/title>/i;
		my $ti = $1;
		$sp =~ /<asin>(.+?)<\/asin>/i;
		my $as = $1;
		push @simti, "<li><a href='$ENV{SCRIPT_NAME}?kw=$as'>$ti<ti>"
	}
	if ($x =~ /<readinglevel>(.+?)<\/readinglevel>/i) {
		$mrc{521}[0] = "0  $1";
	}
	elsif ($x =~ /<audiencerating>(.+?)<\/audiencerating>/i) {
		$mrc{521}[0] = "   $1";
	}
	if ($x =~ /<editorialreview>(.+?)<\/editorialreview>/i) {
		my $e = $1;
		if ($e =~ /<content>(.+?)<\/content>/i) {
			summary($1)
		}
	}

	$mrc{856}[0] = "40 |3 Amazon.com |u http://www.amazon.$q{CT}/exec/obidos/ASIN/$asin";
	$mrc{'000'}[0] = "00000n$mtype" . "m  2200000 a 4500";
	$mrc{'008'}[0] = pack("A6A1A4A4A3A5A1A11A3A1A1", $cdate, "s", $pdate,"","xxu","",$lpflag,"",$lang{$q{CT}},"","d");
	if ($COOK{azconst} =~ /(...) (.)(.) (.+)/) {
		push @{ $mrc{$1} }, "$2$3 $4";
	}
	if ($q{CD}) {
		$q{CD} =~ s/^(...) //;
		push @{ $mrc{$1} }, $q{CD}
	}
	foreach $tag (sort keys %mrc) {
		foreach (@{ $mrc{$tag} }) {
			s/&lt;.+?&gt;//g;
			s/&amp;/&/g;
			s/&#.+?;/ /g;
			if ($tag gt '099' && $tag !~ /856|^9../) { 
				s/(\w)$/$1./;
				if ($q{LC} == 2 && $tag eq '245') { 
					s/([a-z])/\u$1/g;
					s/\|(.)/|\l$1/g;
				}
			}
			$full .= "$tag $_\n"
		}
	}
	if ($q{QX}) {
		$q{FULL} = $full;
		if ($q{QX} == 2) { 
			$q{SAVE} = "batch";
			&batch
		}
		else { &save }
	}
	else {
	$refer = $ENV{HTTP_REFERER};
	if ($refer =~ /amazon/i && $refer !~ /chopac|tag=/) {
		$refer = "http://www.amazon.com/exec/obidos/ASIN/$asin";
	}
	print "<body onLoad='getNames()'>";

	print " Find: <input type='text' class='st' id='mfind'> Replace: <input type='text' class='st' id='mrep'> <input type='button' class='sb' value='Go' onClick='fr()'>";
	print " | <input type='button' class='sb' value='P. CM.' onClick='pcm()' title='Replaces the 300 field with the generic p. cm.'>" if $mtype eq 'a';
	#print " | <input type='button' class='sb' value='Del 650s' onClick='dLine(\"650  4\")' title='Deletes all of the BISAC subject headings in the 650 fields'>";
	print " | <input type='button' class='sb' value='Reformat' onClick='rForm()' title='Sorts the fields'>";
	if ($q{RDA}) { $rdachk = " checked" }
	else { $q{RDA} = 0 }
	print " | <input type='checkbox' class='sb' value='rda' onClick='rdaForm()'$rdachk> RDA Format";
	if ($q{IAM} eq "chopac") {
		&cookie;
		my $base = $COOKS{ref};
		$base =~ s/(.+)\/.+/$1/;
		print "<form action='$base/makemarc.pl' method='post' name='xform'>";
		print "<input type='hidden' name='action' value='send'>";
	}
	else {
		print "<form action='$ENV{SCRIPT_NAME}' method='post' name='xform'>";
	}
	print "<table width='100%' class='recs'>";
	if ($q{IAM} eq "chopac") {
		$textfull = "text";
	}
	else {
		$textfull = "full";
	}
	print "<tr><td width='60%' align='left'><textarea name='$textfull' onKeyUp='getNames()' id='mr'>$full</textarea>";
	print "<td width='20%' class='s' valign='top' align='left'>";
	print "<div id='vn'></div>";
	#print "<select class='button' name='namess' onClick='window.open(\"$ENV{SCRIPT_NAME}?names=\" + form.namess.value,\"Names\",\"width=300 height=500\")'>";
	#print "</select><p>";
	print "<div id='cl'></div></td>";
	print "<td width='20%' valign='top' align='center'>";
	print "</iframe><p class='dtxt'>Similar Titles...</p><ul>";
	print join "", @simti;
	print "</ul><input type='hidden' name='ref' value='$ENV{HTTP_REFERER}'>";
	print "<tr class='lowcontrol'><td><input class='button' type='submit' name='save' value='$svalue'>";
	if ($q{IAM} ne "chopac") {
		print " <i>as</i> <select name='ext' size='1'><option value='lfts'>.lfts</option><option value='mrc'>.mrc</option><option value='marc'>.marc</option><option value='bin'>.bin</option><option value='txt'>.txt</option></select>";
		print "<input class='button' type='submit' name='batch' value='Save to Batch'>";
		print "<input class='button' type='submit' name='empty' value='Empty Batch File'>" if $bai;
	}
	print "<input class='button' type='button' name='fl' value='Worldcat' onClick='location.href=\"http://www.worldcat.org/search/$world\"'>" if $world;
	print "<input class='button' type='button' name='class' value='Classify' onClick='getClass(\"$world\")' title='Suggests call numbers and LCSH'>" if $world;
	print "<input class='button' type='button' name='fl' value='New Search' onClick='location.href=\"azorder.pl\"'>";
	print "</table></form>";
	&footer;

###### A bunch of JavaScript for editing purposes ############################################################
	print <<"_END_FULL_SCRIPT_";
<script>
	// Reformat the form by putting fields in alpha order //
	function rForm() {
		var fRec = document.getElementById('mr');
		var fLines = fRec.value.split('\\n');
		fLines = fLines.sort();
		var i;
		for(i in fLines) {
			if (fLines[i] == '') {
				fLines.splice(i,1)
			}
		}
		fRec.value = fLines.join('\\n') + "\\n"
	}

	function rdaForm() {
		if ($q{RDA} == 1) { location.href='$ENV{SCRIPT_NAME}?ct=$q{CT}&rda=0&kw=$q{KW}' }
		else { location.href='$ENV{SCRIPT_NAME}?ct=$q{CT}&rda=1&kw=$q{KW}' }
	}

	// Change the 300 to "p. cm." //
	function pcm() {
		var fRec = document.getElementById('mr');
		fRec.value = fRec.value.replace(/\\n300.+?\\n/, '\\n300    p. cm.\\n');
	}

	// Completely delete a MARC field //
	function dLine(ln) {
		var r = new RegExp("\\n" + ln + ".+?\\n");
		var fRec = document.getElementById('mr');
		while (fRec.value.match(r)) {
			fRec.value = fRec.value.replace(r, '\\n')
		}
	}

	// Find and replace function //
	function fr() {
		var f = document.getElementById('mfind').value;
		var r = document.getElementById('mrep').value;
		var m = document.getElementById('mr').value;
		var rx = new RegExp(f,"g");
		document.getElementById('mr').value = m.replace(rx, r)
	}

	// Find names to be verified //
	function getNames() {
		var xfull = document.xform.full.value;
		var anames = xfull.match(/[17]00 1  .+/g);
		var nPlace = document.getElementById('vn');
		nPlace.innerHTML = "<b>Verify Names</b><ul>";
		for (a = 0; a < anames.length; a++) {
			anames[a] = anames[a].replace(/[17]00 1  (.+)/, "\$1");
			nPlace.innerHTML += "<li class='n' onClick='window.open(\\"$ENV{SCRIPT_NAME}?names=" + anames[a] + "\\",\\"Names\\",\\"width=300 height=500\\")'>" + anames[a] + "</li>"
		}
		nPlace.innerHTML += "</ul><p>";
	}

	// Insert subject headings from OCLC Classify //
	function inSub(shs) {
		dLine('650  4');
		var fRec = document.getElementById('mr').value;
		for (x=1; x<=shs; x++) {
			fRec = document.getElementById('mr').value;
			document.getElementById('mr').value = fRec + "650  0 " + document.getElementById('sub' + x).innerHTML + "\\n";
		}
		rForm();
	}

	// Insert the LCC from OCLC Classify //
	function inLCC(lcc) {
		var fRec = document.getElementById('mr');
		fRec.value = fRec.value + "050 04 " + lcc;
		rForm()
	}

	// Insert the DCC from OCLC Classify //
	function inDDC(dcc) {
		dLine('082');
		var fRec = document.getElementById('mr');
		fRec.value = fRec.value + "082 04 " + dcc;
		rForm()
	}

	// Get and display Classify data from OCLC //
	function getClass(world) {
		var hR;
		if (window.XMLHttpRequest) {
			hR = new XMLHttpRequest();
		}
		else {
			hR = new ActiveXObject("Msxml2.XMLHTTP");
		}
        	hR.onreadystatechange = function() {
			var s = document.getElementById('cl');
			s.innerHTML = "Searching...";
			if (hR.readyState == 4) {
				s.innerHTML = hR.responseText
			}
		}
		var addr = "$ENV{SCRIPT_NAME}?class=" + world;
        	hR.open('GET', addr, true);
        	hR.send(null);
	}
</script>
_END_FULL_SCRIPT_
	}
}

############## Get the classify data #################################################
sub classify {
	my $opt = "isbn";
	$opt = "upc" if length($q{CLASS}) > 10 && $q{CLASS} !~ /^97[89]/;
	my $x = get("http://classify.oclc.org/classify2/Classify?$opt=$q{CLASS}");
	if ($x =~ /<works>.+?<\/works>/) {
		$x =~ /swid="(.+?)"/;
		$x = get("http://classify.oclc.org/classify2/Classify?swid=$1")
	}
	my $ws = 0;
	while ($x =~ s/<heading .+?>(.+?)<\/heading>//s) {
		$ws++;
		push @sub, $1
	}
	if ($ws) {
		print "<b>Subject Headings</b> <input type='button' class='sb' value='Insert' onClick='inSub($ws)'><ul>";
		my $s = 0;
		foreach (@sub) {
			$s++;
			print "<li id='sub$s'>$_</li>";
		}
		print "</ul>";
	}
	else { print "No OCLC subject data found!" }
	if ($x =~ /<ddc>(.+?)<\/ddc>/s) {
		print "<b>Dewey Call Number</b><ul>";
		$1 =~ /<mostPopular.+?nsfa=["'](.+?)["']/;
		print "<li>$1 <input type='button' class='sb' value='Insert' onClick='inDDC(\"$1\")'></li>";
		print "</ul>"
	}
	if ($x =~ /<lcc>(.+?)<\/lcc>/s) {
		print "<b>LC Call Number</b><ul>";
		$1 =~ /<mostPopular.+?nsfa=["'](.+?)["']/;
		print "<li>$1  <input type='button' class='sb' value='Insert' onClick='inLCC(\"$1\")'></li>";
		print "</ul>"
	}
}

################### Get the verify names data from VIAF #################################################
sub names {
	$nlink= "http://alcme.oclc.org/eprintsUK/services/NACOMatch?method=getCompleteSelectedNameAuthority&xsl=http%3A%2F%2Falcme.oclc.org%2FeprintsUK%2FeprintsUK.xsl&serviceType=rest&isPersonalName=true&name=$q{NAMES}";
	my $x = get($nlink);
	my @l = split /\n/, $x;
	print <<"__END_NAMES__";
<script>
	function takeName(tname,qname) {
		var myRec = window.opener.document.xform.full;
		tname = tname.replace(/\\(/,"|q (");
		tname = tname.replace(/, ([0-9])/,", |d \$1");
		myRec.value = myRec.value.replace(qname, tname);
		window.close()
	}
</script>

__END_NAMES__
	print "<form action='$ENV{SCRIPT_NAME}'><input type='text' value='$q{NAMES}' name='names'><input type='submit' value='Go'></form>";
	foreach (@l) {
		if (/<establishedForm>(.+?)<\/establishedForm>/i) { $eform = $1 }
		if (/<uri>(.+?)<\/uri>/i) { print "<a class='name' href='javascript:void' onClick='takeName(\"$eform\",\"$q{NAMES}\")'><b>$eform</b></a><br>" }
		if (/<citation>(.+?)<\/citation>/i) {
			print "$1<br>"
		}
	}
	print "No records found!" unless $eform;
}

########################## Save a single MARC record or a batch to your local system #########################################
sub save {
	if ($q{SAVE} =~ /batch/i) {
		open SB, "$tmp/$COOK{azmarc}.az";
		$/ = "\t\n";
		while (<SB>) {
			chomp;
			next unless /^000/;
			$smarc .= marc_edit($_)
		}
	}
	else {
		$q{FULL} =~ s/\r//gs;
		$smarc = marc_edit($q{FULL});
	}
	print "Content-disposition: attachment; filename=azmarc.$q{EXT}\n\n";
	print $smarc;
	exit;
}

####################### Save a single MARC record to the batch file #######################################################
sub batch {
	print "Content-type: text/html\n\n";
	if (open BT, ">>$tmp/$COOK{azmarc}.az") {
		print BT "$q{FULL}\t\n";
		print "Record Successfully Saved!";
	}
	else { print "ERROR: Record NOT Saved!" }
}

##################### Delete the batch file ###########################################################################
sub empty {
	unlink "$tmp/$COOK{azmarc}.az";
	print "<script>location.href='$q{REF}'</script>"
}

##################### Calculate the number of non-filing characters for title fields ##################################
sub nofile {
	my $ti = shift;
	my $ib = 0;
	if ($ti =~ /^the /i) { $ib = 4 }
	elsif ($ti =~ /^a /i) { $ib = 2 }
	elsif ($ti =~ /^(an|el) /i) { $ib = 3 }
	return $ib;
}

#################### Change text to lower case with a few exceptions ##################################################
sub lup {
	my $in = shift;
	if ($q{LC} == 0) {
		$in = lc $in;
		$in = ucfirst $in;
		while ($in =~ s/([ .(])([a-z][^a-z])/$1\u$2/g) {}
		$in =~ s/ A / a /g;
	}
	return $in
}

################### Flip the authors' names and assign to 100. All following authors go to 700 ##############
sub auflip {
	my $au = shift;
	return if $au =~ /artist not|various/i;
	my $alt = shift;
	$statement .= "$au, ";
	$au =~ s/(.+) (.+)$/$2, $1/;
	if ($alt) { $autag = $alt }
	elsif ($mrc{100}[0]) { $autag = '700' }
	else { $autag = '100' }
	push @{ $mrc{$autag} }, "1  $au";
}

################## Convert extended characters (usually found in the 520) #################################################
sub summary {
	my $con = shift;
	$con =~ s/&lt;.+?&gt;/ /g;
	my $d = "—";
	$con =~ s/$d/-- /g;
	#$con =~ s/&#239;&#191;&#189;\W+(\w)/ $1/g;
	#$con =~ s//"/g;
	$con =~ s/ +/ /g;
	$con =~ s/^ +| +$//g;
        $con =~ s/(\n\r)|\r|\n//g;
	$mrc{520}[0] = "   $con";
}
