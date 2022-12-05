#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use Data::Dumper;
use FindBin;
use lib $FindBin::Bin;

require "pg_connect_to_database.pl";

my $errmsg;
my $dbh;
my $db = 'sla';

my ( $sql_table , $sth_table );
my ( $sql_comment , $sth_comment );
my ( $sql_index , $sth_index );
my ( $sql_trigger , $sth_trigger );
my ( $sql_fkey_constraint , $sth_fkey_constraint );
my ( $sql_inherit , $sth_inherit );
my ( $sql_table_reference , $sth_table_reference );

######################################################################
#
# Function  : prepare_sql
#
# Purpose   : Prepare the sql statements
#
# Inputs    : (none)
#
# Output    : appropriate messages
#
# Returns   : nothing
#
# Example   : prepare_sql();
#
# Notes     : (none)
#
######################################################################

sub prepare_sql
{

	$sql_table =<<SQL;
select ordinal_position,column_name, data_type, character_maximum_length, column_default, is_nullable
from INFORMATION_SCHEMA.COLUMNS where table_name = \$1
order by ordinal_position;
SQL

	$sth_table = $dbh->prepare($sql_table);
	unless ( defined $sth_table ) {
		die("Can't prepare sql : $sql_table\n$DBI::errstr\n");
	} # UNLESS

	$sql_comment =<<COMMENT;
select *,
obj_description((table_schema||'.'||quote_ident(table_name))::regclass)
from information_schema.tables where table_schema <> 'pg_catalog' and table_name = \$1
COMMENT

	$sth_comment = $dbh->prepare($sql_comment);
	unless ( defined $sth_comment ) {
		die("Can't prepare sql : $sql_comment\n$DBI::errstr\n");
	} # UNLESS

	$sql_index =<<INDEX;
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
and tablename = \$1
ORDER BY tablename, indexname;
INDEX

	$sth_index = $dbh->prepare($sql_index);
	unless ( defined $sth_index ) {
		die("Can't prepare sql : $sql_index\n$DBI::errstr\n");
	} # UNLESS

	$sql_fkey_constraint =<<FKEY;
SELECT
    tc.table_schema,
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_schema AS foreign_table_schema,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM
    information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu 
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu 
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name=\$1
FKEY

	$sth_fkey_constraint = $dbh->prepare($sql_fkey_constraint);
	unless ( defined $sth_fkey_constraint ) {
		die("Can't prepare sql : $sql_fkey_constraint\n$DBI::errstr\n");
	} # UNLESS

	$sql_trigger =<<TRIGGER;
select event_object_schema as table_schema,
       event_object_table as table_name,
       trigger_schema,
       trigger_name,
       string_agg(event_manipulation, ',') as event,
       action_timing as activation,
       action_condition as condition,
       action_statement as definition
from information_schema.triggers
where event_object_table = \$1
group by 1,2,3,4,6,7,8
order by table_schema,
         table_name;
TRIGGER

	$sth_trigger = $dbh->prepare($sql_trigger);
	unless ( defined $sth_trigger ) {
		die("Can't prepare sql : $sql_trigger\n$DBI::errstr\n");
	} # UNLESS

	$sql_inherit =<<INHERIT;
SELECT pg_inherits.*, c.relname AS child, p.relname AS parent
FROM
    pg_inherits JOIN pg_class AS c ON (inhrelid=c.oid)
    JOIN pg_class as p ON (inhparent=p.oid)
WHERE c.relname = \$1
INHERIT

	$sth_inherit = $dbh->prepare($sql_inherit);
	unless ( defined $sth_inherit ) {
		die("Can't prepare sql : $sql_inherit\n$DBI::errstr\n");
	} # UNLESS

	$sql_table_reference =<<TABLE_REFERENCE;
SELECT
    tc.table_schema,
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_schema AS foreign_table_schema,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM
    information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu 
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu 
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY';
TABLE_REFERENCE

	$sth_table_reference = $dbh->prepare($sql_table_reference);
	unless ( defined $sth_table_reference ) {
		die("Can't prepare sql : $sql_table_reference\n$DBI::errstr\n");
	} # UNLESS

	return;
} # end of prepare_sql

######################################################################
#
# Function  : get_table_comment
#
# Purpose   : Get the comment for a table
#
# Inputs    : $_[0] - table name
#
# Output    : appropriate messages
#
# Returns   : IF found THEN the comment ELSE undef
#
# Example   : $comment = get_table_comment($table);
#
# Notes     : (none)
#
######################################################################

sub get_table_comment
{
	my ( $table ) = @_;
	my ( $row , $comment );

	unless ( $sth_comment->execute($table) ) {
		die("Can't execute sql : $sql_comment\n$DBI::errstr\n");
	} # UNLESS

	$comment = undef;
	$row = $sth_comment->fetchrow_hashref();
	if ( defined $row ) {
		$comment = $row->{'obj_description'};
	} # IF

	return $comment;
} # end of get_table_comment

######################################################################
#
# Function  : get_table_indices
#
# Purpose   : Retrieve all of the indices for a table
#
# Inputs    : $_[0] - table name
#
# Output    : appropriate messages
#
# Returns   : IF problem THEN negative ELSE number of indices
#
# Example   : $count = get_table_indices($table);
#
# Notes     : (none)
#
######################################################################

sub get_table_indices
{
	my ( $table ) = @_;
	my ( $row , $count , $indexname , $indexdef );

	unless ( $sth_index->execute($table) ) {
		die("Can't execute sql : $sql_index\n$DBI::errstr\n");
	} # UNLESS

	$count = 0;
	while ( $row = $sth_index->fetchrow_hashref() ) {
		$count += 1;
		if ( $count == 1 ) {
			print "\nIndices for table $table\n";
		} # IF
		print "Index $row->{'indexname'} : $row->{'indexdef'}\n";
	} # WHILE

	return $count;
} # end of get_table_indices

######################################################################
#
# Function  : get_table_fkey_constraints
#
# Purpose   : Get the foreign key constraints for a table
#
# Inputs    : $_[0] - table name
#
# Output    : requested report
#
# Returns   : nothing
#
# Example   : get_table_fkey_constraints($table);
#
# Notes     : (none)
#
######################################################################

sub get_table_fkey_constraints
{
	my ( $table ) = @_;
	my ( $row , $count );

	unless ( $sth_fkey_constraint->execute($table) ) {
		die("Can't execute sql : $sql_fkey_constraint\n$DBI::errstr\n");
	} # UNLESS

	$count = 0;
	while ( $row = $sth_fkey_constraint->fetchrow_hashref() ) {
		$count += 1;
		if ( $count == 1 ) {
			print "\nForeign key constraints for table $table\n";
			print qq~
$row->{'constraint_name'} : FOREIGN KEY ($row->{'column_name'}) REFERENCES $row->{'foreign_table_name'}($row->{'foreign_column_name'})
~;
		} # IF
	} # WHILE

	return;
} # end of get_table_fkey_constraints

######################################################################
#
# Function  : get_table_triggers
#
# Purpose   : Get the triggers for a table
#
# Inputs    : $_[0]
#
# Output    : requested information
#
# Returns   : nothing
#
# Example   : get_table_triggers($table);
#
# Notes     : (none)
#
######################################################################

sub get_table_triggers
{
	my ( $table ) = @_;
	my ( $row , $count );

	unless ( $sth_trigger->execute($table) ) {
		die("Can't execute sql : $sql_trigger\n$DBI::errstr\n");
	} # UNLESS

	$count = 0;
	while ( $row = $sth_trigger->fetchrow_hashref() ) {
		$count += 1;
		if ( $count == 1 ) {
			print "\nTriggers for table $table\n";
		} # IF
		print qq~
($count) $row->{'trigger_name'} --> $row->{'activation'} $row->{'event'} ON $row->{'table_name'} FOR EACH ROW $row->{'definition'}
~;
	} # WHILE

	return;
} # end of get_table_triggers

######################################################################
#
# Function  : get_table_inheritance
#
# Purpose   : Get a list of tables that a table inherits from
#
# Inputs    : $_[0] - table name
#
# Output    : requested information
#
# Returns   : nothing
#
# Example   : get_table_inheritance($table)
#
# Notes     : (none)
#
######################################################################

sub get_table_inheritance
{
	my ( $table ) = @_;
	my ( $row , $count );

	unless ( $sth_inherit->execute($table) ) {
		die("Can't execute sql : $sql_inherit\n$DBI::errstr\n");
	} # UNLESS

	$count = 0;
	while ( $row = $sth_inherit->fetchrow_hashref() ) {
		$count += 1;
		if ( $count == 1 ) {
			print "\n$table inherits from :\n";
		} # IF
		print "$row->{'parent'}\n";
	} # WHILE

	return;
} # end of get_table_inheritance

######################################################################
#
# Function  : get_table_refs
#
# Purpose   : Get a list of tables that refer to a table
#
# Inputs    : $_[0] - table name
#
# Output    : requested information
#
# Returns   : nothing
#
# Example   : get_table_refs($table);
#
# Notes     : (none)
#
######################################################################

sub get_table_refs
{
	my ( $table ) = @_;
	my ( $row , $count );

	unless ( $sth_table_reference->execute() ) {
		die("Can't execute sql : $sql_table_reference\n$DBI::errstr\n");
	} # UNLESS

	$count = 0;
	while ( $row = $sth_table_reference->fetchrow_hashref() ) {
		if ( $row->{'foreign_table_name'} eq $table ) {
			$count += 1;
			if ( $count == 1 ) {
				print "\n$table is referenced by the tables :\n";
			} # IF
			print "$row->{'table_name'}\n";
		} # IF
	} # WHILE

	return;
} # end of get_table_refs

######################################################################
#
# Function  : describe_table
#
# Purpose   : Print table descriptive information.
#
# Inputs    : $_[0] - tablename
#
# Output    : table description
#
# Returns   : nothing
#
# Example   : describe_table($tablename);
#
# Notes     : (none)
#
######################################################################

sub describe_table
{
	my ( $table ) = @_;
	my ( $row , $buffer , $comment , $count );

	print "\n==  $table  ==\n\n";

	unless ( $sth_table->execute($table) ) {
		die("Can't execute sql : $sql_table\n$DBI::errstr\n");
	} # UNLESS

	while ( $row = $sth_table->fetchrow_hashref() ) {
		foreach my $colname ( 'ordinal_position' , 'column_name' , 'data_type' , 'character_maximum_length' , 'column_default' , 'is_nullable' ) {
			unless ( defined $row->{$colname} ) {
				$row->{$colname} = "";
			} # UNLESS
		} # FOREACH
		print qq~
Ordinal      $row->{'ordinal_position'}
Colname      $row->{'column_name'}
Data Type    $row->{'data_type'}
Char Maxlen  $row->{'character_maximum_length'}
Col Default  $row->{'column_default'}
Is Null ?    $row->{'is_nullable'}
~;

	} # WHILE

	$sth_table->finish();

	$comment = get_table_comment($table);
	if ( defined $comment ) {
		print "\n$table : $comment\n";
	} # IF
	else {
		print "\n$table : [no comment]\n";
	} # ELSE

	$count = get_table_indices($table);
	if ( $count <= 0 ) {
		print "No indices found for $table\n";
	} # IF

	get_table_fkey_constraints($table);

	get_table_triggers($table);

	get_table_inheritance($table);

	get_table_refs($table);

	return;
} # end of describe_table

########
# MAIN #
########

my ( $status , $buffer );

unless ( 0 < scalar @ARGV ) {
	die("Usage : $0 table_name [... table_name]\n");
} # UNLESS
 
$buffer = localtime(time());
print "\n$buffer\n";

my $driver  = "Pg";
my $database = "postdb1";
my $port = 5432;
my $host = "127.0.0.1";
my $dsn = "DBI:$driver:dbname = $database;host = 127.0.0.1;port = $port";
my $userid = "someone";
my $password = "mypassword";

$dbh = pg_connect_to_database(\$errmsg,
	{ "dbname" => $database , "userid" => $userid , "password" => $password } );

unless ( $dbh ) {
	warn("\n+++ $errmsg\n");
	die("\nFarewell ...\n");
} # UNLESS

prepare_sql();

foreach my $table ( @ARGV ) {
	describe_table($table);
} # FOREACH

$sth_table->finish();
$sth_comment->finish();
$sth_index->finish();
$sth_fkey_constraint->finish();
$sth_trigger->finish();
$sth_inherit->finish();
$sth_table_reference->finish();

$dbh->disconnect();

exit 0;
