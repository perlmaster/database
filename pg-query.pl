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

my %options = ( "d" => 0 , "h" => 0 , "w" => 0 , "r" => 0 , "D" => "postdb1" , "u" => "someone" );
my $dbh;
my $report_handle;
my @field_values = ();

######################################################################
#
# Function  : sig_handler
#
# Purpose   : Signal handler
#
# Inputs    : (none)
#
# Output    : (none)
#
# Returns   : nothing
#
# Example   : sig_handler();
#
# Notes     : (none)
#
######################################################################

sub sig_handler
{
	error("\nsig_handler($_[0]) :\n");

	exit 1;
} # end of sig_handler

######################################################################
#
# Function  : run_query
#
# Purpose   : Run the specified query
#
# Inputs    : $_[0] - buffer containing a query
#
# Output    : formatted query output
#
# Returns   : IF problem THEN negative ELSE zero
#
# Example   : $status = run_query($sql);
#
# Notes     : (none)
#
######################################################################

sub run_query
{
	my ( $sql ) = @_;
	my ( $sth , @colnames , $colname , $status , $num_cols , $i );
	my ( $length , $column , $row , $maxlen , $hex );
	my ( $ref_names , @rows , @row , $row_num );

	print $report_handle "\n>>  $sql  <<\n";

	# executing the SQL statement.

	$sth = $dbh->prepare($sql);
	unless ( defined $sth ) {
		error("can't prepare sql : $sql\n$DBI::errstr\n");
		$dbh->disconnect();
		die("Goodbye ...\n");
	} # UNLESS
	unless ( $sth->execute ) {
		error("can't execute sql : $sql\n$DBI::errstr\n");
		$dbh->disconnect();
		die("Goodbye ...\n");
	} # UNLESS

	$num_cols = $sth->{NUM_OF_FIELDS};
	$ref_names = $sth->{'NAME'};
	@colnames = @$ref_names;
	$maxlen = (sort { $b <=> $a} map { length $_ } @colnames)[0];

	@rows = ();
	$row_num = 0;
	while ( $row = $sth->fetchrow_hashref ) {
		$row_num += 1;
		@row = ();
		for ( $i = 0 ; $i <= $#colnames ; ++$i ) {
			$colname = $colnames[$i];
			$column = $row->{$colname};
			unless ( defined $column ) {
				$column = " ";
			} # UNLESS
			push @row,$column;
		} # FOR over columns in row
		push @rows,[ @row ];
		if ( exists $options{"F"} ) {
			$column = $row->{$options{"F"}};
			unless ( defined $column ) {
				$column = "";
			} # UNLESS
			push @field_values,"'$column'";
		} # IF
	} # WHILE over all rows in table
	$sth->finish();
	if ( exists $options{"F"} ) {
		print "\nValues for $options{'F'} : ",join(" , ",@field_values),"\n";
	} # IF

	foreach my $row ( @rows ) {
		@row = @$row;
		print $report_handle "\n";
		for ( $i = 0 ; $i < $num_cols ; ++$i ) {
			printf $report_handle "%-${maxlen}.${maxlen}s %s\n",$colnames[$i],$row[$i];
		} # FOR
	} # FOREACH

	print $report_handle "\n${row_num} rows returned from the query\n";

	return 0;
} # end of run_query

######################################################################
#
# Function  : run_query_wide
#
# Purpose   : Run the specified query
#
# Inputs    : $_[0] - buffer containing a query
#
# Output    : formatted query output
#
# Returns   : IF problem THEN negative ELSE zero
#
# Example   : $status = run_query_wide($sql);
#
# Notes     : (none)
#
######################################################################

sub run_query_wide
{
	my ( $sql ) = @_;
	my ( $sth , @colnames , $colname , $status , $num_cols , $i );
	my ( $length , $column , $row , $maxlen , $hex );
	my ( $ref_names , @rows , @row , $row_num , $index , $field_name_index );

	print $report_handle "\n>>  $sql  <<\n";

	# executing the SQL statement.

	$sth = $dbh->prepare($sql);
	unless ( defined $sth ) {
		error("can't prepare sql : $sql\n$DBI::errstr\n");
		$dbh->disconnect();
		die("Goodbye ...\n");
	} # UNLESS
	unless ( $sth->execute ) {
		error("can't execute sql : $sql\n$DBI::errstr\n");
		$dbh->disconnect();
		die("Goodbye ...\n");
	} # UNLESS

	$num_cols = $sth->{NUM_OF_FIELDS};
	$ref_names = $sth->{'NAME'};
	@colnames = @$ref_names;
	$maxlen = (sort { $b <=> $a} map { length $_ } @colnames)[0];
	if ( exists $options{"F"} ) {
		$field_name_index = -1;
		for ( $index = 0 ; $index <= $#colnames ; ++$index ) {
			if ( $options{"F"} eq $colnames[$index] ) {
				$field_name_index = $index;
				last;
			} # IF
		} # FOR
		if ( $field_name_index < 0 ) {
			print "\nError : '$options{'F'}' not one of the column names : ",join(" , ",@colnames),"\n";
			return;
		} # IF
	} # IF

	@rows = ();
	$row_num = 0;
	while ( $row = $sth->fetchrow_arrayref ) {
		$row_num += 1;
		@row = @$row;
		for ( $i = 0 ; $i <= $#colnames ; ++$i ) {
			unless ( defined $row[$i] ) {
				$row[$i] = " ";
			} # UNLESS
		} # FOR over columns in row
		push @rows,[ @row ];
		if ( exists $options{"F"} ) {
			push @field_values,$row[$field_name_index];
		} # IF
	} # WHILE over all rows in table
	$sth->finish();
	if ( exists $options{"F"} ) {
		print "\nValues for $options{'F'} : ",join(" , ",@field_values),"\n\n";
	} # IF

	if ( $options{'r'} ) {
		@rows = reverse @rows;
	} # IF

	print_list_of_rows(\@rows,\@colnames,"=",0,$report_handle);

	print $report_handle "\n${row_num} rows returned from the query\n";

	return 0;
} # end of run_query_wide

########
# MAIN #
########

my ( $status , $errmsg , $pass );

$status = getopts("hdwF:u:D:",\%options);

if ( $status == 0 || $options{'h'} || 0 == scalar @ARGV ) {
	die("Usage : $0 [-dhw] [-u username] [-D dbname] [-F field_name] query_term [... query_term]\n");
} # IF

$Data::Dumper::Indent = 1;  # this is a somewhat more compact output style
$Data::Dumper::Sortkeys = 1; # sort alphabetically

$report_handle = \*STDOUT;

$pass = get_password("Enter password for user $options{'u'} on database $options{'D'} ==> ");

$dbh = pg_connect_to_database(\$errmsg,
	{ "dbname" => $options{"D"} , "userid" => $options{'u'} , "password" => $pass } );

print "Opened database successfully\n";

my $tablename = (0 == scalar @ARGV) ? 'customer' : $ARGV[0];
my $sql = join(" ",@ARGV);
print "\nsql is : $sql\n\n";

if ( $options{'w'} ) {
	$status = run_query_wide($sql);
} # IF
else {
	$status = run_query($sql);
} # ELSE

$dbh->disconnect; # disconnect from databse

exit 0;
