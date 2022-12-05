#!/usr/bin/perl -w

######################################################################
#
# File      : pg_connect_to_database.pl
#
# Author    : Barry Kimelman
#
# Created   : August 15, 2022
#
# Purpose   : Connect to my personal postgresql database
#
# Notes     : (none)
#
######################################################################

use strict;
use warnings;
use Getopt::Std;
use DBI;
use FindBin;
use lib $FindBin::Bin;

######################################################################
#
# Function  : pg_connect_to_database
#
# Purpose   : Connect to postgresql database
#
# Inputs    : $_[0] - reference to error message buffer
#             $_[1] - optional ref to hash of connection parameters
#
# Output    : appropriate messages
#
# Returns   : IF problem THEN undef ELSE database handle
#
# Example   : $handle = pg_connect_to_database(\$errmsg,\%parms);
# Example   : $handle = pg_connect_to_database(\$errmsg,
#                 { "dbname" => "mydatabase" , "userid" => "someone" , "AutoCommit" => 0 ,"RaiseError" => 0 } );
#
# Notes     : (none)
#
######################################################################

sub pg_connect_to_database
{
	my ( $ref_errmsg , $ref_parms ) = @_;
	my ( $driver , %parameters , $handle , $dsn , $database , $userid , $password , $port , $host );

	$$ref_errmsg = "";

	%parameters = ( "dbname" => "?" , "userid" => "?" , "password" => "?" , "RaiseError" => 1 ,
					"port" => 5432 , "host" => "127.0.0.1" , "AutoCommit" => 1);
	if ( defined $ref_parms ) {
		foreach my $parm ( keys %parameters ) {
			if ( exists $ref_parms->{$parm} ) {
				$parameters{$parm} = $ref_parms->{$parm};
			} # IF
		} # FOREACH
	} # IF

	$driver = "Pg";
	$dsn = "DBI:$driver:dbname = $parameters{'dbname'};host = $parameters{'host'};port = $parameters{'port'}";

	$handle = DBI->connect($dsn, $parameters{'userid'}, $parameters{'password'},
						{ RaiseError => $parameters{'RaiseError'} , "AutoCommit" => $parameters{'AutoCommit'} } );
	unless ( defined $handle ) {
		$$ref_errmsg = $DBI::errstr;
		return undef;
	} # UNLESS

	return $handle;
} # end of pg_connect_to_database

1;
