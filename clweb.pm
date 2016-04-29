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
# 5 Whaler Court
# Third Lake, IL 60030-2620
# USA
# http://www.libcat.org
# blp1569@gmail.com

sub qstring {
	my $in = shift;
	my @qs = split /&/, $in;
	foreach $_ (@qs) {
		(my $term, my $data) = split /=/;
		$term = uc $term;
		$data =~ tr/+/ /;
		$data =~ s/%(..)/chr(hex($1))/eg;
		if ($out{$term}) { $out{$term} .= "\t$data" }
		else { $out{$term} = $data }
		}
	return %out;
	}
sub content {
	print "Content-Type: text/html\n\n";
	}
sub cookie {
        my @c = split /; /, $ENV{HTTP_COOKIE};
	foreach (@c) {
	    /(.+)=(.+)/;
	    $COOKS{$1}=$2;
	}
}
sub sql_date {
	my $in = shift;
	$in =~ s/(....)-(..)-(..)/$2\/$3\/$1/;
	$in =~ s/^0|(\W)0/$1/g;
	return $in;
}
1;
