#!/usr/bin/perl -w

######################################################################
#
# File      : mysql_mysql_get_table_columns_info.pl
#
# Author    : Barry Kimelman
#
# Created    : December 1, 2022
#
# Purpose   : Describe the structure of mysql database tables
#
# Notes     : (none)
#
######################################################################

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use DBI;
use database;

######################################################################
#
# Function  : mysql_get_table_columns_info
#
# Purpose   : Get list of column names and corresponding data types for a table.
#
# Inputs    : $_[0] - name of table
#             $_[1] - name of schema containing table
#             $_[2] - reference to hash to receive data
#             $_[3] - reference to array to receive ordered list of column names
#             $_[4] - reference to error message buffer
#
# Output    : (none)
#
# Returns   : IF problem THEN negative ELSE number of columns
#
# Example   : $num_cols = mysql_get_table_columns_info($table,$schema,\%columns,\@colnames,\$errmsg);
#
# Notes     : (none)
#
######################################################################

sub mysql_get_table_columns_info
{
	my ( $tablename , $schema , $ref_columns , $ref_colnames , $ref_errmsg ) = @_;
	my ( $dbh , $sql , $sth , $ref , $db , $host , $user , $pwd , @fields , $colname );
	my ( $choices , @choices );

	$$ref_errmsg = "";
	%$ref_columns = ();
	@$ref_colnames = ();

	$db = "INFORMATION_SCHEMA";	# your username (= login name  = account name )
	$host = "127.0.0.1";    # = "localhost", the server your are on.
	$user = $database::db_user;		# your Database name is the same as your account name.
	$pwd = $database::db_pass;	# Your account password

	# connect to the database.

	my %attr = ( "PrintError" => 0 , "RaiseError" => 0 );
	$dbh = DBI->connect( "DBI:mysql:$db:$host", $user, $pwd, \%attr);
	unless ( defined $dbh ) {
		$$ref_errmsg = "Error connecting to $db : $DBI::errstr";
		return -1;
	} # UNLESS

	$sql =<<SQL;
SELECT column_name,data_type,ordinal_position,is_nullable,column_comment,
CHARACTER_MAXIMUM_LENGTH,NUMERIC_PRECISION,NUMERIC_SCALE,COLUMN_TYPE,COLUMN_KEY,EXTRA
FROM columns
WHERE table_name = '$tablename' AND table_schema = '$schema'
order by ordinal_position
SQL
	$sth = $dbh->prepare($sql);
	unless ( defined $sth ) {
		$$ref_errmsg = "can't prepare sql : $sql\n$DBI::errstr";
		$dbh->disconnect();
		return -1;
	} # UNLESS
	unless ( $sth->execute ) {
		$$ref_errmsg = "can't execute sql : $sql\n$DBI::errstr";
		$dbh->disconnect();
		return -1;
	} # UNLESS

	%$ref_columns = ();
	while ( $ref = $sth->fetchrow_arrayref ) {
		@fields = @$ref;
		$colname = $fields[0];
		push @$ref_colnames,$colname;
		$$ref_columns{$colname}{'data_type'} = $fields[1];
		$$ref_columns{$colname}{'ord'} = $fields[2];
		$$ref_columns{$colname}{'nullable'} = $fields[3];
		$$ref_columns{$colname}{'comment'} = $fields[4];
		$$ref_columns{$colname}{'maxlen'} = $fields[5];
		$$ref_columns{$colname}{'numeric_precision'} = $fields[6];
		$$ref_columns{$colname}{'numeric_scale'} = $fields[7];
		$$ref_columns{$colname}{'column_type'} = $fields[8];
		$$ref_columns{$colname}{'column_key'} = $fields[9];
		$$ref_columns{$colname}{'extra'} = $fields[10];
		if ( $$ref[1] eq "DATE" ) {
		} # IF
		if ( $fields[1] eq 'enum' ) {
			$choices = $fields[8];
			$choices =~ s/^enum.//g;
			$choices =~ s/.$//g;
			$choices =~ s/'//g;
			@choices = split(/,/,$choices);
			$$ref_columns{$colname}{'enum_choices'} = [ @choices ];
		} # IF
		else {
			$$ref_columns{$colname}{'enum_choices'} = undef;
		} # ELSE
	} # WHILE
	$sth->finish();
	$dbh->disconnect();

	return scalar keys %$ref_columns;
} # end of mysql_get_table_columns_info

1;
