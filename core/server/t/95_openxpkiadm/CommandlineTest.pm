package CommandlineTest;
use strict;
use warnings;

# Core modules
use File::Temp qw( tempfile );
use Symbol qw(gensym);
use IPC::Open3 qw( open3 );
use List::Util qw( min );
use Cwd;

# CPAN modules
use Test::More;
use Test::Deep;


use base qw( Exporter );

our @EXPORT = qw(
    openxpkiadm_test
    cert_import_ok
    cert_import_failsok
    cert_list_ok
    cert_list_failsok
);

#
# Test "openxpkiadm certificate import".
#
# Positional parameters:
# * $test_cert - Container with certificate data (OpenXPKI::Test::CertHelper::Database::PEM)
# * @args - Additional arguments to pass on the command line
#
sub cert_import_ok {
    my ($test_cert, @args) = @_;

    my $id = $test_cert->db->{identifier};
    _cert_import($test_cert, qr/ success .* $id /msxi, 1, @args);
}

#
# Test "openxpkiadm certificate import" and expect it to fail with the given
# error message.
#
# Positional parameters:
# * $test_cert - Container with certificate data (OpenXPKI::Test::CertHelper::Database::PEM)
# * $error_re - Expected error string (regex or string)
# * @args - Additional arguments to pass on the command line
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

    openxpkiadm_test(
        [ 'certificate', 'import', '--file', $filename, ],
        \@args,
        $success_expected,
        $expected_msg_re,
        sprintf('import "%s"', $test_cert->label)
    );
}

#
# Test "openxpkiadm certificate list".
#
# Positional parameters:
# * $expected_output_re - RegEx (or ArrayRef of RegExes) with the expected output
# * @args - Additional arguments to pass on the command line
#
sub cert_list_ok {
    my ($expected_output_re, @args) = @_;
    openxpkiadm_test([ 'certificate', 'list' ], \@args, 1, $expected_output_re, 'list certificates');
}

#
# Test "openxpkiadm certificate list" and expect it to fail with the given
# error message.
#
# Positional parameters:
# * $expected_output_re - RegEx|String (or ArrayRef of RegExes|Strings) with the expected output
# * @args - Additional arguments to pass on the command line
#
sub cert_list_failsok {
    my ($expected_output_re, @args) = @_;
    openxpkiadm_test([ 'certificate', 'list' ], \@args, 0, $expected_output_re, 'list certificates');
}

#
# Test "openxpkiadm xxx" and check its output against the given Regexes/strings.
#
# Positional parameters:
# $basecmd - base command of openxpkiadm which will not be shown in test message (ArrayRef)
# $args - additional arguments to openxpkiadm that will be shown (ArrayRef)
# $shall_succeed - whether we expect the test to succeed or fail (Bool)
# $expected_output_re - RegEx|String (or ArrayRef of AND combined RegExes|Strings) with the expected output
# $descr - base test description (String)
#
sub openxpkiadm_test {
    # $basecmd and $args are separated to provide a nicer output message
    my ($basecmd, $args, $shall_succeed, $expected_output_re, $descr) = @_;

    $expected_output_re = [ $expected_output_re ] unless ref $expected_output_re eq 'ARRAY';

    my $msg = sprintf('%s%s %s',
        $descr,
        scalar(@$args) ? " (".join(" ", @$args).")" : "",
        $shall_succeed ? "" : "returns error"
    );

    # run import
    my $output = gensym; # filehandle

    my $relpath = getcwd."/bin/openxpkiadm"; # current working dir should be core/server, so try binary at core/server/bin/
    my @cmd = (-x $relpath ? $relpath : "openxpkiadm", @$basecmd, @$args);
    my $pid = open3(0, $output, 0, @cmd); waitpid($pid, 0);

    # read output
    local $/;
    chomp(my $output_str = <$output>);

    # check exit code
    my $error = $? >> 8;
    if ( ($error and $shall_succeed) or (not $error and not $shall_succeed) ) {
        diag "Error: " . join(' ', @cmd) . " exited with $error";
        diag $output_str;
        fail $msg;
        return;
    }

    # Grep the output lines for each Regex (or string converted to regex)
    # and count each occurrance
    my @occurrances = map {
        my $re = ref($_) eq 'Regexp' ? $_ : qr/ \Q$_\E /msx;
        $output_str =~ $re
            or diag "Output does not match $re:\n$output_str"
    } @$expected_output_re;

    my $all_found = min(@occurrances);
    ok $all_found, $msg;
}