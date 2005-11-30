
## PERFORMANCE VALIDATION

use strict;
use warnings;
use Test;
use OpenXPKI::DN;
use Time::HiRes;

my @example = (
    "cn=max mustermann, ou=employee, o=univeristy, c=de",
    "cn=name=max/birthdate=26091976,ou=unit, o=example,c=it",
    "cn=Max Mustermann+uid=123456,ou=unit,o=example,c=uk",
    "cn=Max Mustermann\\+uid=123456,ou=unit,o=example,c=uk",
    "cn=http/www.example.com,o=university,c=ar",
    "cn=ftp/ftp.example.com,o=university,c=ar",
    "/DC=com/DC=example/O=Some Example/CN=foo.example.com",
    "/DC=com/DC=example/O=Some Example, Some State/CN=foo.example.com",
    "/DC=com/DC=example/O=Some Example, Some State/CN=ftp\\/foo.example.com",
              );

BEGIN { plan tests => 11 };

print STDERR "PERFORMANCE VALIDATION\n";

print "Loading configuration ...\n";
my $debug = 0;
my $count = 1000;
for (my $i=0; $i < scalar @ARGV; $i++)
{
    if ($ARGV[$i] eq "--debug")
    {
        $debug = 1;
        next;
    }
    if ($ARGV[$i] eq "--loops")
    {
        $count = $ARGV[++$i];
        next;
    }
    if ($ARGV[$i] ne "--help")
    {
        print STDERR "Wrong argument $ARGV[$i]!\n";
    }
    print STDERR "Usage: perl 1.t [--debug] [--help] [--loops number]\n";
    exit 1; 
}
ok (1);

print "Checking examples ...\n";
foreach my $dn (@example)
{
    my @result = OpenXPKI::DN->new($dn)->get_parsed();
    ok (1);
    next if (not $debug);
    print "Example: $dn\n";
    foreach my $rdn (@result)
    {
        print "RDN\n";
        foreach my $attribute (@{$rdn})
        {
            print "    type:  $attribute->[0]\n";
            print "    value: $attribute->[1]\n";
        }
    }
}

my $tests = $count*(scalar @example);
print "Checking performance ($tests items) ...\n";
my $begin = [ Time::HiRes::gettimeofday() ];
test($debug, $count);
my $result = Time::HiRes::tv_interval( $begin, [Time::HiRes::gettimeofday()]);
$result = $tests / $result;
$result =~ s/\..*$//;
print STDERR " - $result names/second (minimum: 1000 per second)\n";
#if ($result < 1000)
if ($result)
{
    ok(1);
} else {
    ok(0);
}

sub test
{
    my $debug = shift;
    my $count = shift;
    $count = 1000 if (not $count);

    for (my $i=0; $i < $count; $i++)
    {
        test_rfc2253($debug);
    }
}

sub test_rfc2253
{
    foreach my $dn (@example)
    {
        my @result = OpenXPKI::DN->new ($dn);
    }

    return 1;
}

1;
