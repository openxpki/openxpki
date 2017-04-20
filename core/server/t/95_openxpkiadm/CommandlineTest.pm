package CommandlineTest;
use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );
use File::Temp qw( tempfile );
use Symbol qw(gensym);
use IPC::Open3 qw( open3 );

# CPAN modules
use Test::More;
use Test::Deep;


use base qw( Exporter );

our @EXPORT = qw( cert_import_ok cert_import_failsok );

#
# Test certificate import via "openxpkiadm certificate import".
#
# Positional parameters:
# * $test_cert - Container with certificate data (OpenXPKI::Test::CertHelper::Database::PEM)
# * @args - Arguments to pass on the command line
#
sub cert_import_ok {
    my ($test_cert, @args) = @_;

    my $id = $test_cert->db->{identifier};
    _cert_import($test_cert, qr/ success .* $id /msxi, 1, @args);
}

#
# Test certificate import via "openxpkiadm certificate import" and expect it to
# fail with the given error message.
#
# Positional parameters:
# * $test_cert - Container with certificate data (OpenXPKI::Test::CertHelper::Database::PEM)
# * $error_re - Expected error string (regex)
# * @args - Arguments to pass on the command line
#
sub cert_import_failsok {
    my ($test_cert, $error_re, @args) = @_;
    _cert_import($test_cert, $error_re, 0, @args);
}

sub _cert_import {
    my ($test_cert, $expected_msg_re, $success_expected, @args) = @_;

    my ($fh, $filename) = tempfile(UNLINK => 1);
    print $fh $test_cert->data or die "Could not write test certificate data";
    close $fh or die "Could not close test certificate file";

    _openxpkiadm(
        [ 'certificate', 'import', '--file', $filename, ],
        \@args,
        $success_expected,
        $expected_msg_re,
        sprintf('import "%s"', $test_cert->label)
    );
}

sub _openxpkiadm {
    # $basecmd and $args are separated to provide a nicer output message
    my ($basecmd, $args, $success_expected, $expected_output_re, $descr) = @_;

    my $msg = sprintf('%s%s %s',
        $descr,
        scalar(@$args) ? " (".join(" ", @$args).")" : "",
        $success_expected ? "successful" : "fails with $expected_output_re"
    );

    # run import
    my @cmd = ('openxpkiadm', @$basecmd, @$args);

    my $output = gensym;
    my $pid = open3(0, $output, 0, @cmd); waitpid($pid, 0);
    local $/;
    chomp(my $str = <$output>);

    my $error = $? >> 8;
    if ( ($error and $success_expected) or (not $error and not $success_expected) ) {
        diag "Error: " . join(' ', @cmd) . " exited with $error";
        diag $str;
        fail $msg;
        return;
    }

    like $str, $expected_output_re, $msg;
}