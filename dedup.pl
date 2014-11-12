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
#          0.3 - Add conditional testing of additional fields before de-duplication. 
#          0.2 - Removed extra Symphony environment declarations. 
#          0.1 - Added -i. 
#          0.0 - Dev. 
#
####################################################

use strict;
use warnings;
use vars qw/ %opt /;
use Getopt::Std;

my $VERSION        = qq{0.3};
my @COLUMNS_WANTED = ();
my @COLUMNS_CHECK  = (); # Values of additional columns that will select which duplicate to keep.

#
# Message about this program and how to use it.
#
sub usage()
{
    print STDERR << "EOF";

	usage: $0 [-dix] [-f<columns>] [-l|g<columns>]
De-duplicates a column based file, based on similarity of arbitrary but specific column content.
The column numbers are one-based. Any column index that is out of range will be ignored with a 
message and results will be undefined. If no column number is selected the all lines will be 
output as is. The content of any outputted line will never be modified. The order of output 
shall be undefined and will necessarily vary from the original file.

Additionally you can add a conditional, final check with the -l or -g flag. 
'-l' sets the columns that will allows you to specify that on any duplicate row,
choose the lower of the two values in the specified column(s). -g specifies allows you to specify
the greater of the two values in the specified columns.

**NOTE: comparisons are made on string values within columns, therefore are sorted alpha-numerically
so '10' is less than '2' because the first character of '10' is less than the first character of '3'.

The input is expected to be on standard in.

 -d             : Print debug information.
 -i             : Ignore letter casing.
 -f[c1,c2,...cn]: Columns used in comparison. If the columns doesn't exist it is ignored.
 -g[c1,c2,...cn]: Columns used in comparison to select which duplicate to save, '-g' greater
                  of the duplicate value in the column. See '-l' for less than.
 -l[c1,c2,...cn]: Columns used in comparison to select which duplicate to save, '-l' lesser
                  of the duplicate value in the column. See '-g' for greater than.
                  Use one or the other.
 -n             : Coerce -l and -g values into numbers if possible.
 -x             : This (help) message.

example: $0 -x
example: cat file.txt | $0 -fc5,c1,c4 
         Would de-dup records that are the same in column 5, 1, and 4 in that order. De-duplication
         will only occur on the fields that do exist, that is, out of range indexes are ignored with
         a warning message.
example: cat file.txt | $0 -fc5,c1,c4 -lc2
         Would select the lower value column 2 as the tie-breaker if a duplicate is found.
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

# Parses the column request flags into usable values and stores them
# in the appropriate arrays.
# param:  string of columns separated by ','.
# param:  Destination array reference for column values.
# return: <none>
sub getColumnRequested( $$ )
{
	my $args = shift;
	my $finalArray = shift;
	# Since we can't split if there is no delimiter character, let's introduce one if there isn't one.
	$args .= "," if ( $args !~ m/,/ );
	my @cols = split( ',', $args );
	foreach my $colNum ( @cols )
	{
		# Columns are designated with 'c' prefix to get over the problem of perl not recognizing 
		# '0' as a legitimate column number.
		if ( $colNum =~ m/c\d{1,}/ )
		{
			$colNum =~ s/c//; # get rid of the 'c' because it causes problems later.
			push( @{$finalArray}, trim( $colNum ) );
		}
	}
	if ( scalar @{$finalArray} == 0 )
	{
		print STDERR "**Error no valid columns selected.\n";
		usage();
	}
}

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'dif:g:l:nx';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ( $opt{'x'} );
	if ( $opt{'f'} )
	{
		getColumnRequested( $opt{'f'}, \@COLUMNS_WANTED );
		print STDERR "columns requested for dedup match: '@COLUMNS_WANTED'\n" if ( $opt{'d'} and $opt{'f'} );
	}
	if ( $opt{'l'} )
	{
		getColumnRequested( $opt{'l'}, \@COLUMNS_CHECK );
		print STDERR "columns requested for less than conditional selection: '@COLUMNS_CHECK'\n" if ( $opt{'d'} and $opt{'l'} );
	}
	elsif ( $opt{'g'} )
	{
		getColumnRequested( $opt{'g'}, \@COLUMNS_CHECK ); # Array reference.
		print STDERR "columns requested for greater than conditional selection: '@COLUMNS_CHECK'\n" if ( $opt{'d'} and $opt{'g'} );
	}
}

#
# Returns the key composed of the selected fields.
# param:  string to extract column values from the input.
# param:  List of desired fields, or columns.
# return: string composed of each string selected as column pasted together without trailing spaces.
sub getKey( $$ )
{
	my $line          = shift;
	my $wantedColumns = shift;
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
	# Pull out the values from the line that will make up the key for storage in a hash table.
	for ( my $i = 0; $i < scalar(@{$wantedColumns}); $i++ )
	{
		my $j = ${$wantedColumns}[$i];
		$j -= 1;
		# we have to iterate over a zero-based array, but user can't input -fc0 the compiler complains.
		if ( defined $columns[ $j ] and exists $columns[ $j ] )
		{
			my $cols = $columns[ $j ];
			$cols = lc( $columns[ $j ] ) if ( $opt{ 'i' } );
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

# Determines which of the duplicates should be selected and returns the line that best matches.
# param: 'l' - less or 'g' - greater match condition.
# param: line1 to compare.
# param: line2 to compare.
# return: the line that successfully matched the criteria.
sub choose_duplicate( $$$ )
{
	my $keyWord = shift;
	my $lineOne = shift;
	my $lineTwo = shift;
	my $keyOne  = getKey( $lineOne, \@COLUMNS_CHECK );
	my $keyTwo  = getKey( $lineTwo, \@COLUMNS_CHECK );
	if ( $opt{'n'} and $keyOne =~ m/\d{1,}/ and $keyTwo =~ m/\d{1,}/ )
	{
		if ( $keyWord eq 'l' and $keyOne < $keyTwo )
		{
			return $lineOne;
		}
		elsif ( $keyWord eq 'g' and $keyOne > $keyTwo )
		{
			return $lineOne;
		}
		return $lineTwo;
	}

	if ( ($keyWord eq 'l') and ($keyOne lt $keyTwo) )
	{
		return $lineOne;
	}
	elsif ( $keyWord eq 'g' and $keyOne gt $keyTwo )
	{
		return $lineOne;
	}
	return $lineTwo;
}

init();

my $hashRef = {};
while ( <> )
{
	my $line = trim( $_ ); #chomp;
	my $key  = getKey( $line, \@COLUMNS_WANTED );
	# impose a less than conditional selection on duplicates.
	if ( $opt{'l'} ) 
	{
		if ( $hashRef->{ $key } )
		{
			$hashRef->{ $key } = choose_duplicate( 'l', $hashRef->{ $key }, $line );
			next;
		}
	}
	elsif ( $opt{'g'} ) 
	{
		if ( $hashRef->{ $key } )
		{
			$hashRef->{ $key } = choose_duplicate( 'g', $hashRef->{ $key }, $line );
			next;
		}
	}
	$hashRef->{ $key } = $line;
}

# Output results
while ( my ($key, $value) = each(%$hashRef) ) 
{
	print "$value\n";
}

# EOF
