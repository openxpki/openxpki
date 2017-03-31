#!/usr/bin/env perl
#
# Converts the generated PEM private key files into Perl code to be inserted
# into OpenXPKI::Test::CertHelper::Database.
#
use strict;
use warnings;

use File::Find;

die "Base path where certificates reside must be specified as first parameter"
    unless $ARGV[0] and -d $ARGV[0];

sub get_files {
    my ($path, $extension) = @_;
    my $filemap = {};
    find(
        sub {
            return unless / \. \Q$extension\E $/msxi;
            my $name = $_; $name =~ s/ \. [^\.]+ $//msxi;
            # slurp
            open (my $fh, $_) or die "Could not open $File::Find::name";
            my @pem = <$fh>; close ($fh);
            chomp @pem;
            $filemap->{$name} = join('\n', @pem);
        },
       $path
    );
    return $filemap;
}

my $pkcs7 = get_files($ARGV[0], "p7b");
my $privkeys = get_files($ARGV[0], "pem");

print "sub _build_pkcs7 {\n    return {\n";
printf "        '%s' => \"%s\",\n", $_, $pkcs7->{$_} for sort keys %$pkcs7;
print "    };\n}\n";

print "sub _build_private_keys {\n    return {\n";
printf "        '%s' => \"%s\",\n", $_, $privkeys->{$_} for sort keys %$privkeys;
print "    };\n}\n";
