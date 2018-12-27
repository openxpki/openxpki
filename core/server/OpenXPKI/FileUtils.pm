## OpenXPKI::FileUtils
## Written 2006 by Alexander Klink for the OpenXPKI project
## largely based on code in OpenXPKI.pm written by Michael Bell
## and Martin Bartosch for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::FileUtils;

use strict;
use warnings;
use English;

use Class::Std;

use OpenXPKI::Debug;
use OpenXPKI::Exception;

use File::Spec;
use File::Temp;
use Fcntl qw( :DEFAULT );

my %safe_filename_of :ATTR; # a hash of filenames created with safe_tmpfile
my %safe_dir_of      :ATTR; # a hash of directories created with safe_tmpdir
my %temp_handles     :ATTR;
my %temp_dir         :ATTR;

sub BUILD {
    my ($self, $ident, $arg_ref ) = @_;

    $temp_handles{$ident} = [];

    if ($arg_ref && $arg_ref->{TMP}) {
        $temp_dir{$ident} = $arg_ref->{TMP};
    } else {
        $temp_dir{$ident} = '/tmp';
    }
}

sub read_file {
    my $self = shift;
    my $ident = ident $self;
    my $filename = shift;

    if (! defined $filename) {
    OpenXPKI::Exception->throw (
        message => 'I18N_OPENXPKI_FILEUTILS_READ_FILE_MISSING_PARAMETER',
        );
    }

    if (! -e $filename) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_FILEUTILS_READ_FILE_DOES_NOT_EXIST',
            params  => {'FILENAME' => $filename});
    }

    if (! -r $filename) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_FILEUTILS_READ_FILE_NOT_READABLE',
            params  => {'FILENAME' => $filename});
    }

    my $result = do {
    open my $HANDLE, '<', $filename;
    if (! $HANDLE) {
        OpenXPKI::Exception->throw (
        message => 'I18N_OPENXPKI_FILEUTILS_READ_FILE_OPEN_FAILED',
        params  => {'FILENAME' => $filename});
    }
    # slurp mode
    local $INPUT_RECORD_SEPARATOR;     # long version of $/
    <$HANDLE>;
    };

    return $result;
}


sub write_file {
    my $self     = shift;
    my $ident    = ident $self;
    my $arg_ref  = shift;
    my $filename = $arg_ref->{FILENAME};
    my $content  = $arg_ref->{CONTENT};

    if (! defined $filename) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_FILEUTILS_WRITE_FILE_NO_FILENAME_SPECIFIED',
        );
    }

    if (! defined $content) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_FILEUTILS_WRITE_FILE_NO_CONTENT_SPECIFIED',
        );
    }

    if ((-e $filename) and
        not $arg_ref->{FORCE} and
        (not ref $self or
         not $safe_filename_of{$ident} or
         not $safe_filename_of{$ident}->{$filename})) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_FILEUTILS_WRITE_FILE_ALREADY_EXISTS',
            params  => {'FILENAME' => $filename});
    }

    my $mode = O_WRONLY | O_TRUNC;
    if (! -e $filename) {
    $mode |= O_EXCL | O_CREAT;
    }

    my $HANDLE;
    if (not sysopen($HANDLE, $filename, $mode))
    {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_FILEUTILS_WRITE_FILE_OPEN_FAILED',
            params  => {'FILENAME' => $filename});
    }
    print {$HANDLE} $content;
    close $HANDLE;

}

sub get_safe_tmpfile {
    ##! 1: 'start'
    my $self = shift;
    my $ident = ident $self;
    my $arg_ref = shift;

    ##! 2: 'build template'
    my $template = $self->__get_safe_template ($arg_ref);

    ##! 2: 'build tmp file'
    my $fh = File::Temp->new( TEMPLATE => $template, UNLINK => 1 );
    if (! $fh) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_FILEUTILS_GET_SAFE_TMPFILE_MAKE_FAILED'
        );
    }
    my $filename = $fh->filename;
    close $fh;

    ##! 2: 'fix mode'
    chmod 0600, $filename;
    $safe_filename_of{$ident}->{$filename} = 1;

    ##! 1: 'end: $filename'
    return $filename;
}

sub get_safe_tmpdir {
    ##! 1: 'start'
    my $self = shift;
    my $ident = ident $self;
    my $arg_ref = shift;

    ##! 2: 'build template'
    my $template = $self->__get_safe_template ($arg_ref);

    ##! 2: 'build tmp file'
    my $dir = File::Temp::mkdtemp($template);
    if (! -d $dir) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_FILEUTILS_GET_SAFE_TMPDIR_MAKE_FAILED',
            params  => {'DIR' => $dir});
    }

    ##! 2: 'fix mode'
    chmod 0700, $dir;
    $safe_dir_of{$ident}->{$dir} = 1;

    ##! 1: 'end: $filename'
    return $dir;
}

=head2 get_tmp_handle

Create a temporary file and return the object handle of it.
The return value can be used in string context to get the name of the
directory created. The handle will be held open by the class so it will
stay in the filesystem until the class is destroyed.

=cut

sub get_tmp_handle {

    my $self = shift;
    my $ident = ident $self;

    my $fh = File::Temp->new(
        TEMPLATE => $self->__get_safe_template({ TMP => $temp_dir{$ident} }),
    );
    # enforce umask
    chmod 0600, $fh->filename;
    push @{$temp_handles{$ident}}, $fh;
    return $fh;

}

=head2 get_tmp_dir

Create a temporary directory and return the object handle of it.
The return value can be used in string context to get the name of the
directory created. The handle will be held open by the class so it will
stay in the filesystem until the class is destroyed.

=cut

sub get_tmp_dirhandle {

    my $self = shift;
    my $ident = ident $self;

    my $fh = File::Temp->newdir(
        TEMPLATE => $self->__get_safe_template({ TMP => $temp_dir{$ident} }),
    );
    # enforce umask
    chmod 0700, $fh->dirname;
    push @{$temp_handles{$ident}}, $fh;
    return $fh;

}

=head2 write_temp_file

Expects the content to write as argument. Creates a temporary file handle
using get_tmp_handle and writes the data to it. The filehandle is closed
and the name of the file is returned.

=cut

sub write_temp_file {

    my $self = shift;
    my $ident = ident $self;
    my $content = shift;

    if (! defined $content) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_FILEUTILS_WRITE_FILE_NO_CONTENT_SPECIFIED',
        );
    }

    my $fh = $self->get_tmp_handle();
    my $filename = $fh->filename;
    print {$fh} $content;
    close $fh;

    return $filename ;

}

sub __get_safe_template
{
    ##! 1: 'start'
    my $self = shift;
    my $ident = ident $self;
    my $arg_ref = shift;

    ##! 2: 'check TMP'
    if (not exists $arg_ref->{TMP}) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_FILEUTILS_GET_SAFE_TEMPLATE_MISSING_TMP');
    }
    if (not -d $arg_ref->{TMP}) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_FILEUTILS_GET_SAFE_TEMPLATE_DIR_DOES_NOT_EXIST',
            params => {DIR => $arg_ref->{TMP}});
    }

    ##! 2: 'build template'
    return File::Spec->catfile($arg_ref->{TMP}, "openxpki${PID}XXXXXXXX");
}

sub cleanup {

    my $self = shift;
    my $ident = ident $self;

    foreach my $file (keys %{$safe_filename_of{$ident}}) {
        if (-e $file) {
            unlink($file);
            delete $safe_filename_of{$ident}->{$file};
        }
    }

    $temp_handles{$ident} = [];

    return 1;
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

This method creates a safe temporary file and returns the filename.

=head2 get_safe_tmpdir

Example: my $dir = $self->get_tmpdir ({TMP => "/tmp"});

This method creates a safe temporary directory and returns the path to it.
