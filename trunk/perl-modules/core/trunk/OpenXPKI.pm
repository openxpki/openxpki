## OpenXPKI
##
## Written 2005 by Michael Bell and Martin Bartosch
## for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
package OpenXPKI;

use strict;
use warnings;
#use diagnostics;
use utf8;
#use encoding 'utf8';

use OpenXPKI::VERSION;
our $VERSION = $OpenXPKI::VERSION::VERSION;

use English qw (-no_match_vars);
use XSLoader;
XSLoader::load ("OpenXPKI", $VERSION);

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use DateTime;
use Scalar::Util qw( blessed );
use Fcntl qw (:DEFAULT);

use File::Spec;
use File::Temp;

use vars qw (@ISA @EXPORT_OK);
require Exporter;
@ISA = qw (Exporter);
@EXPORT_OK = qw (read_file write_file get_safe_tmpfile);

sub read_file
{
    my $self = shift;
    my $filename = shift;

    if (! defined $filename) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_READ_FILE_MISSING_PARAMETER",
	    );
    }

    if (! -e $filename)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_READ_FILE_DOES_NOT_EXIST",
            params  => {"FILENAME" => $filename});
    }

    if (! -r $filename)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_READ_FILE_NOT_READABLE",
            params  => {"FILENAME" => $filename});
    }

    my $result = do {
	open my $HANDLE, "<", $filename;
	if (! $HANDLE) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_READ_FILE_OPEN_FAILED",
		params  => {"FILENAME" => $filename});
	}
        ## looks like this does not work
        ## "\x82 is no utf8" is the message (10000010) - perhaps an encoding problem?
        ## binmode $HANDLE, ":utf8";
        ## print STDERR "filename: $filename\n";

	# slurp mode
	local $INPUT_RECORD_SEPARATOR;     # long version of $/
	<$HANDLE>;
    };

    return $result;
}


sub write_file
{
    my $self     = shift;
    my $keys     = { @_ };
    my $filename = $keys->{FILENAME};
    my $content  = $keys->{CONTENT};

    if (! defined $filename)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WRITE_FILE_NO_FILENAME_SPECIFIED",
	    );
    }

    if (! defined $content)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WRITE_FILE_NO_CONTENT_SPECIFIED",
	    );
    }

    ## checks on safely created files are senseless
    if ((-e $filename) and
        not $keys->{FORCE} and
        (not ref $self or
         not $self->{SAFE_FILENAME} or
         not $self->{SAFE_FILENAME}->{$filename}))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WRITE_FILE_ALREADY_EXISTS",
            params  => {"FILENAME" => $filename});
    }


    my $mode = O_WRONLY | O_TRUNC;
    if (! -e $filename) {
	$mode |= O_EXCL | O_CREAT;
    }

    my $HANDLE;
    if (not sysopen($HANDLE, $filename, $mode))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WRITE_FILE_OPEN_FAILED",
            params  => {"FILENAME" => $filename});
    }
    ## deactivated because reading creates a lot of trouble
    ## binmode $HANDLE, ":utf8";
    print {$HANDLE} $content;
    close $HANDLE;

    return 1;
}

sub get_safe_tmpfile
{
    ##! 1: "start"
    my $self = shift;
    my $keys = shift;

    ##! 2: "check TMP"
    if (not exists $keys->{TMP})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_GET_SAFE_TMPFILE_MISSING_TMP");
    }
    if (not -d $keys->{TMP})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_GET_SAFE_TMPFILE_DIR_DOES_NOT_EXIST",
            params => {DIR => $keys->{TMP}});
    }

    ##! 2: "build template"
    my $template = File::Spec->catfile($keys->{TMP}, "openxpkiXXXXXX");

    ##! 2: "build tmp file"
    my ($fh, $filename) = File::Temp::mkstemp($template);
    if (! $fh) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_GET_SAFE_TMPFILE_MAKE_FAILED",
            params  => {"FILENAME" => $filename});
    }
    close $fh;

    ##! 2: "fix mode"
    chmod 0600, $filename;
    $self->{SAFE_FILENAME}->{$filename} = 1;

    ##! 1: "end: $filename"
    return $filename;
}

1;

__END__

=head1 Name

OpenXPKI - base module for all OpenXPKI core modules.

=head1 Exported functions

Exported function are function which can be imported by every other
object. These function are exported to enforce a common behaviour of
all OpenXPKI modules for debugging and error handling.

C<use OpenXPKI::API qw (debug);>

=head2 debug

You should call the function in the following way:

C<$self-E<gt>debug ("help: $help");>

All other stuff is generated fully automatically by the debug function.

=head1 Functions

=head2 read_file

Example: $self->read_file($filename);


=head2 write_file

Example: $self->write_file (FILENAME => $filename, CONTENT => $data);

The method will raise an exception if the file already exists unless
the optional argument FORCE is set. In this case the method will overwrite
the specified file.

Example: $self->write_file (FILENAME => $filename, CONTENT => $data, FORCE => 1);

=head2 get_safe_tmpfile

Example: my $file = $self->get_tmpfile ({TMP => "/tmp"});

This method creates a safe temporary file and return the filename.
