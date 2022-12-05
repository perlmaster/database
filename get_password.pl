#!/usr/bin/perl -w

######################################################################
#
# File      : get_password.pl
#
# Author    : Barry Kimelman
#
# Created   : December 11, 2014
#
# Purpose   : Read password entered by user without echoing
#
######################################################################

use strict;
use warnings;
use Getopt::Std;
use Term::ReadKey;
use FindBin;
use lib $FindBin::Bin;

######################################################################
#
# Function  : get_password
#
# Purpose   : Decrypt the data in a file.
#
# Inputs    : $_[0] - prompt
#
# Output    : password propt
#
# Returns   : password entered by user
#
# Example   : $pass = get_password("Enter password ==> ");
#
# Notes     : (none)
#
######################################################################

sub get_password
{
	my ( $prompt ) = @_;
	my ( $password );

	ReadMode( "noecho");
	if ( defined $prompt && $prompt =~ m/\S/ ) {
		print "$prompt";
	} # IF
	$password = <STDIN>;
	chomp $password;
	ReadMode ("original") ;
	print "\n";

	return $password;
} # end of get_password

1;
