#!/usr/bin/perl -w
####################################################
#
# Perl source file for project dedup 
# Purpose:
# Method:
#
# De-duplicates a column based file, based on similarity of arbitrary but specific column content.
#    Copyright (C) 2013  Andrew Nisbet
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# Author:  Andrew Nisbet, Edmonton Public Library
# Created: Thu Oct 23 13:21:32 MDT 2014
# Rev: 
#          0.1 - Added -i. 
#          0.0 - Dev. 
#
####################################################

use strict;
use warnings;
use vars qw/ %opt /;
use Getopt::Std;

my $VERSION        = qq{0.1};
my @COLUMNS_WANTED = ();

#
# Message about this program and how to use it.
#
sub usage()
{
    print STDERR << "EOF";

	usage: $0 [-x]
De-duplicates a column based file, based on similarity of arbitrary but specific column content.
The column numbers are one-based. Any column index that is out of range will be ignored with a 
message and results will be undefined. If no column number is selected the all lines will be 
output as is. The content of any outputted line will never be modified. The order of output 
shall be undefined and will necessarily vary from the original file.

The input is expected to be on standard in.

 -d             : Print debug information.
 -i             : Ignore letter casing.
 -f[c0,c1,...cn]: Columns from file 2 used in comparison. If the columns doesn't exist it is ignored.
 -x             : This (help) message.

example: $0 -x
example: cat file.txt | $0 -fc5,c1,c4 
         Would de-dup records that are the same in column 5, 1, and 4 in that order. De-duplication
         will only occur on the fields that do exist, that is, out of range indexes are ignored with
		 a warning message.
Version: $VERSION
EOF
    exit;
}

#
# Trim function to remove whitespace from the start and end of the string.
# param:  string to trim.
# return: string without leading or trailing spaces.
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'dif:x';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ( $opt{'x'} );
	if ( $opt{'f'} )
	{
		# Since we can't split if there is no delimiter character, let's introduce one if there isn't one.
		$opt{'f'} .= "," if ( $opt{'f'} !~ m/,/ );
		my @cols = split( ',', $opt{'f'} );
		foreach my $colNum ( @cols )
		{
			# Columns are designated with 'c' prefix to get over the problem of perl not recognizing 
			# '0' as a legitimate column number.
			if ( $colNum =~ m/c\d{1,}/ )
			{
				$colNum =~ s/c//; # get rid of the 'c' because it causes problems later.
				push( @COLUMNS_WANTED, trim($colNum) );
			}
		}
		if ( scalar @COLUMNS_WANTED == 0 )
		{
			print STDERR "**Error, '-f' flag used but no valid columns selected.\n";
			usage();
		}
	}
	print STDERR "columns requested from second file: '@COLUMNS_WANTED'\n" if ( $opt{'d'} and $opt{'f'} );
}

#
# Returns the key composed of the selected fields.
# param:  string to extract column values from.
# return: string composed of each string selected as column pasted together without trailing spaces.
sub getKey
{
	my $line          = shift;
	my @wantedColumns = @_;
	my $key           = "";
	my @columns = split( '\|', $line );
	# If the line only has one column that is couldn't be split then return the entire line as 
	# key. Duplicate lines will be removed only if they match entirely.
	if ( scalar( @columns ) < 2 )
	{
		print STDERR "\$key>$key<\n" if ( $opt{'d'} );
		return $line;
	}
	my @newLine = ();
	foreach my $i ( @wantedColumns )
	{
		$i -= 1;
		# we have to iterate over a zero-based array, but user can't input -fc0 the compiler complains.
		if ( defined $columns[ $i ] and exists $columns[ $i ] )
		{
			my $cols = $columns[ $i ];
			$cols = lc( $columns[ $i ] ) if ( $opt{ 'i' } );
			push( @newLine, $cols );
		}
	}
	# it doesn't matter what we use as a delimiter as long as we are consistent.
	$key = join( ' ', @newLine );
	# if the key is empty we will fill it with line, and lines that match completely will be removed.
	$key = $line if ( $key eq "" );
	print STDERR "\$key>$key<\n" if ( $opt{'d'} );
	return $key;
}

init();

my $hashRef = {};
while ( <> )
{
	my $line = trim( $_ ); #chomp;
	my $key  = getKey( $line, @COLUMNS_WANTED );
	$hashRef->{ $key } = $line;
}

# Output results
while ( my ($key, $value) = each(%$hashRef) ) 
{
	print "$value\n";
}

# EOF
