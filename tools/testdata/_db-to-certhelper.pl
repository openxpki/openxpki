#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Carp;
use English;
use Data::Dumper;
use File::Basename;
use FindBin qw( $Bin );

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use Test::More;
use DateTime;

# Project modules
use lib "$Bin/../../core/server";
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Context qw( CTX );

#
# Print all certificates as database hashes
#
OpenXPKI::Server::Init::init({
    TASKS  => ['config_versioned','log','dbi'],
    SILENT => 1,
    CLI => 1,
});

#mysqldump -h $OXI_TEST_DB_MYSQL_DBHOST -u $OXI_TEST_DB_MYSQL_USER -p"$OXI_TEST_DB_MYSQL_PASSWORD" \
#    --set-charset --no-create-info \
#    --skip-comments --skip-add-locks --skip-disable-keys \
#    --extended-insert --complete-insert --single-transaction \
#    $OXI_TEST_DB_MYSQL_NAME > /code-repo/dump-certificates.sql

my $dbh = CTX('dbi')->select(
    from_join => 'aliases|a identifier=identifier certificate|c',
    columns => [ qw( a.alias a.group_id a.generation c.* ) ],
);

print "sub _build_certs {\n    return {\n";

while (my $data = $dbh->fetchrow_hashref) {
    my $label = (split("=", (split(",", $data->{subject}))[0]))[1];
    my $internal_id = ($data->{group_id}//"") eq "root" ? $data->{pki_realm}."-".$data->{alias} : $data->{alias};
    $internal_id =~ s/-/_/g;
    print "        '$internal_id' => OpenXPKI::Test::CertHelper::Database::PEM->new(\n";
    print "            label => '$label',\n";
    print '            db => {'."\n                ";
    print join "\n                ",
        map {
            my $val = $data->{$_};
            my $qc = "'";
            # Multiline attributes
            if (m/^(data|public_key)$/) {
                $val =~ s/\r?\n/\\n/g if $val;  # Convert newlines to "\n"
                $qc = '"';                      # Double quotes
            }
            sprintf("%s => %s,%s",
                $_,
                (defined $val ? "$qc$val$qc" : "undef"),
                ($_ =~ /^not(before|after)$/ ? " # ".DateTime->from_epoch(epoch => $val)->datetime : ""),
            )
        }
        sort
        grep { $_ !~ /^ ( alias | group_id | generation ) $/msx }
        keys %$data;
    print "\n            },\n";
    print '            db_alias => {'."\n                ";
    print join "\n                ",
        map {
            my $val = $data->{$_};
            sprintf("%s => %s,",
                $_,
                (defined $val ? "'$val'" : "undef"),
            )
        }
        sort
        grep { /^ ( alias | group_id | generation ) $/msx }
        keys %$data;
    print "\n            },\n        ";
    print "),\n\n";
};

print "    };\n}\n";
