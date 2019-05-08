#!/usr/bin/env perl
#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Carp;
use English;
use Data::Dumper;
use File::Basename;
use FindBin qw( $Bin );
use File::Find;

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use Test::More;
use DateTime;

# Project modules
use lib "$Bin/../../core/server";
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Context qw( CTX );


sub get_files {
    my ($path, $extension) = @_;
    my $filemap = {};
    find(
        sub {
            return unless / \. \Q$extension\E $/msxi;
            my $name = $_; $name =~ s/ \. [^\.]+ $//msxi;
            # slurp
            open (my $fh, '<', $_) or die "Could not open $File::Find::name";
            my @pem = <$fh>; close ($fh);
            chomp @pem;
            $filemap->{$name} = join('\n', @pem);
        },
       $path
    );
    return $filemap;
}

#
# Converts the generated PEM private key files into Perl code to be inserted
# into OpenXPKI::Test::CertHelper::Database.
#
die "Base path where certificates reside must be specified as first parameter"
    unless $ARGV[0] and -d $ARGV[0];

my $pkcs7 = get_files($ARGV[0], "p7b");
my $crl = get_files($ARGV[0], "crl");
my $privkeys = get_files($ARGV[0], "pem"); # used later on

print "sub _build_pkcs7 {\n    return {\n";
printf "        '%s' => \"%s\",\n", $_, $pkcs7->{$_} for sort keys %$pkcs7;
print "    };\n}\n";

print "sub _build_crl {\n    return {\n";
printf "        '%s' => \"%s\",\n", $_, $crl->{$_} for sort keys %$crl;
print "    };\n}\n";

#
# Print all certificates as database hashes
#
OpenXPKI::Server::Init::init({
    TASKS  => ['config_versioned','log','dbi'],
    SILENT => 1,
    CLI => 1,
});

my $dbh = CTX('dbi')->select(
    from_join => 'aliases|a identifier=identifier certificate|c',
    columns => [ qw( a.alias a.group_id a.generation c.* ) ],
);

print "sub _build_certs {\n    return {\n";

while (my $data = $dbh->fetchrow_hashref) {
    my $label = (split("=", (split(",", $data->{subject}))[0]))[1];
    my $internal_id = ($data->{group_id}//"") eq "root" ? $data->{pki_realm}."-".$data->{alias} : $data->{alias};

    print "        '$internal_id' => OpenXPKI::Test::CertHelper::Database::Cert->new(\n";
    print "            label => '$label',\n";
    print "            name => '$internal_id',\n";
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
    print "\n            },\n";
    printf "            private_key => \"%s\",\n", $privkeys->{$internal_id};
    print "        ),\n\n";
};

print "    };\n}\n";
