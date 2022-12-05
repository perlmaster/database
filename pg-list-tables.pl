#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Std;
use DBI;
use Data::Dumper;
use FindBin;
use lib $FindBin::Bin;

require "get_password.pl";
require "pg_connect_to_database.pl";

my %options = ( "d" => 0 , "h" => 0 , "D" => 'postdb1' , 'u' => 'someone' );

my ( $status , $dbh , $errmsg , $pass );

$status = getopts("hdu:D:",\%options);

if ( $status == 0 || $options{'h'} ) {
	die("Usage : $0 [-dh] [-u userid] [-D dbname]\n");
} # UNLESS

$Data::Dumper::Indent = 1;  # this is a somewhat more compact output style
$Data::Dumper::Sortkeys = 1; # sort alphabetically

$pass = get_password("Enter password for user $options{'u'} on database $options{'D'} ==> ");

$dbh = pg_connect_to_database(\$errmsg,
	{ "dbname" => $options{"D"} , "userid" => $options{'u'} , "password" => $pass } );

unless ( defined $dbh ) {
	die("Connection failed\n$errmsg\n");
} # UNLESS

print "Opened database successfully\n";

my $sql =<<SQL;
SELECT *
FROM pg_catalog.pg_tables
WHERE schemaname != 'pg_catalog' AND
    schemaname != 'information_schema';
SQL

my $sth = $dbh->prepare($sql);
unless ( defined $sth ) {
	warn("can't prepare sql : $sql\n$DBI::errstr\n");
	$dbh->disconnect();
	die("Goodbye ...\n");
} # UNLESS
unless ( $sth->execute ) {
	warn("can't execute sql : $sql\n$DBI::errstr\n");
	$dbh->disconnect();
	die("Goodbye ...\n");
} # UNLESS

my $space;

while ( my $ref = $sth->fetchrow_hashref ) {
	if ( defined $ref->{'tablespace'} ) {
		$space = $ref->{'tablespace'};
	} # IF
	else {
		$space = "";
	} # ELSE
	
	print qq~
Schema          $ref->{'schemaname'}
Tablename       $ref->{'tablename'}
Owner           $ref->{'tableowner'}
Tablespace      $space
Indexes ?       $ref->{'hasindexes'}
Rules ?         $ref->{'hasrules'}
Triggers ?      $ref->{'hastriggers'}
Row Security    $ref->{'rowsecurity'}
~;
} # WHILE over all rows in table
$sth->finish();

$dbh->disconnect; # disconnect from databse

exit 0;
