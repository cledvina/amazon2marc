# *********************************************************************
#                         Copyright Notice.
# *********************************************************************
#
# Copyright (C) 2011 Charles Ledvina.
#
# This file is part of Amazon to MARC Converter.
#
# See COPYRIGHT.txt for the copyright notice applying to Amazon to MARC
# Converter as a whole.
#
# This file is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This file is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this file; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
# The license may be found online at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html .
#
# Charles Ledvina
# cledvina@chopac.org


$Ssp = chr(31);
$Fsp = chr(30);
$Rsp = chr(29);
sub marc_edit {
	my($t,$n,$dir,$body,$leader,$rlen,$bstart,$kee,$flen,$fpos);
	my $txtfile = shift;
	my $type = shift;
	my $blvl = shift;
	my @e = localtime(time);
	my $etime = $e[5] + 1900;
	$etime .= zfill($e[4]+1,2);
	$etime .= zfill($e[3],2);
	$etime .= zfill($e[2],2);
	$etime .= zfill($e[1],2);
	$etime .= zfill($e[0],2);
	$etime .= '.0';
	%tag = ();
	if ($txtfile =~ /\n/) { @txt = split /\n\r|\r\n|\n|\r/, $txtfile }
	else {
		open TXT, $txtfile;
		@txt = <TXT>;
		close TXT;
		}
	foreach (@txt) {
		chomp;
		s/(\d\d\d) //;
		$t = $1;
		if ($t =~ /000|LDR/i) { 
			$leader = $_;
			next;
			}
		elsif ($t lt '010') { $n = '' }
		else { 
			s/(..) //;
			$n = $1;
			s/^/${Ssp}a/ unless m/^\|/;
			s/(|\s+)\|(.)(\s+|)/$Ssp$2/g;
			}
		push @{ $tag{$t} }, "$n$_$Fsp";
		}
	$tag{'005'}[0] = $etime . $Fsp;
	foreach $kee (sort(keys %tag)) {
		foreach (@{ $tag{$kee} }) {
			$fpos += $flen;
			$flen = zfill(length($_),4);
			$fpos = zfill($fpos,5);
			$dir .= "$kee$flen$fpos";
			$body .= $_;
			}
		}
	$dir .= $Fsp;
	$body .= $Rsp;
	$bstart = zfill(24 + length($dir),5);
	$rlen = zfill($bstart + length($body),5);
	if ($leader) { $leader =~ s/.....(.......).....(.+)/$rlen$1$bstart$2/ }
	else { $leader = pack("A5A1A1A1A4A5A7", $rlen,'n',$type,$blvl,'  22',$bstart,'   45 0') }
	return "$leader$dir$body";
	}

sub marc_read {
	my $raw = shift;
	$raw =~ s/\|/ /g;
	%out = ();
	my ($reclen,$datapos);
	my $ldr = unpack("A24",$raw);
	($reclen,$x,$out{TYPE},$out{BLVL},$x,$datapos) = unpack("A5A1A1A1A4A5",$ldr);
	my $dir = substr($raw,24,$datapos-24);
	$out{FULL} = "000 $ldr\n";
	my $body = substr($raw,$datapos,$reclen-$datapos);
	while ($dir =~ s/(...)(....)(.....)//) {
		my $fpos = $3;
		my $flen = $2;
		my $fn = $1;
		my $fdata = substr($body,$fpos,$flen);
		$fdata =~ s/$Fsp//g;
		my $index = $fdata;
		my ($ind,@subf) = split /$Ssp/, $fdata;
		if ($fn gt '009') {
			@inds = split //, $ind;
			push @{ $out{"IND1_$fn"} }, $inds[0];
			push @{ $out{"IND2_$fn"} }, $inds[1];
			}
		foreach (@subf) { s/(.)(.+)/push @{ $out{"$fn$1"} }, $2/e }
		$fdata =~ s/^(..)$Ssp(a)/$1 /;
		$fdata =~ s/$Ssp(.)/ |$1 /g;
		$out{FULL} .= "$fn $fdata\n";
		$index =~ s/^....//g if $fn gt '009';
		if ($fn =~ /6\d\d/) {
			$index =~ s/$Ssp\d.+//;
			$index =~ s/$Ssp./--/g
			}
		else {$index =~ s/$Ssp./ /g}
		push @{ $out{$fn} }, $index;
		}
	($out{CREATED},$out{DTYPE},$out{DATE},$out{DATE2},$x,$out{LANG}) = unpack("A6A1A4A4A20A3", $out{'008'}[0]);
	$out{TITLE} = $out{'245a'}[0];
	$out{TITLE} .= " $out{'245b'}[0]" if $out{'245b'}[0];
	$out{TITLE} .= " $out{'245n'}[0]" if $out{'245n'}[0];
	$out{TITLE} .= " $out{'245p'}[0]" if $out{'245p'}[0];
	return %out;
}

sub strip {
	$_ = shift;
	s/^0+//g;
	$_ = 0 unless $_;
	return $_
	}
sub trim {
	$_ = shift;
	my $type = shift;
	if ($type) { s/^\s+|\W+$//g }
	else { s/^\s+|\s+$//g }
	return $_
	}
sub zfill {
	my $n = shift;
	my $l = shift;
	$n = "0" x ($l - length($n)) . $n if length($n) < $l;
	return $n;
	}
1;
