## OpenXPKI::FileUtils
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


=head1 OpenXPKI::FileUtils

Helper class for file operations and temp file management.

=head2 Parameters

The constructor expects arguments as a hash.

=item TMP

The parent directory to use for all temporary items created. If not
set I</tmp> is used.

=back

=cut

sub BUILD {
    my ($self, $ident, $arg_ref ) = @_;

    $temp_handles{$ident} = [];

    if ($arg_ref && $arg_ref->{TMP}) {
        $temp_dir{$ident} = $arg_ref->{TMP};
    } else {
        $temp_dir{$ident} = '/tmp';
    }
}

=head1 Functions

=head2 read_file I<filename>, I<encoding>

Reads the content of the given filename and returns it as string, pass
I<utf8> as second parameter to read the file in utf8 mode. Throws an
exception if the file can not be read.

=cut

sub read_file {
    my $self = shift;
    my $ident = ident $self;
    my $filename = shift;
    my $encoding = shift || '';

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

    my $enc = '';
    if ($encoding eq 'utf8') {
        $enc = ':encoding(UTF-8)';
    }

    my $result = do {
        open my $HANDLE, "<$enc", $filename;
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

=head2 write_file I<{ FILENAME, CONTENT, FORCE }>

Expects a hash with the keys I<CONTENT> and I<FILENAME>. The method will
B<NOT> overwrite an existing file but throw an exception if the target
already exists, unless I<FORCE> is passed a true value or the filename
is a tempfile created by I<get_safe_tmpfile> before.

=cut

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

=head2 get_safe_tmpfile { TMP }

Create an emtpty tempfile and returns its name. You can pass a hash with
the key I<TMP> set to the parent directory to use, if not set the
directory given to the constructor is used.

The file will B<NOT> be removed unless you call the I<cleanup> method of
this class instance.

=cut

sub get_safe_tmpfile {
    ##! 1: 'start'
    my $self = shift;
    my $ident = ident $self;
    my $arg_ref = shift;

    ##! 2: 'build template'
    my $template = $self->__get_safe_template($arg_ref);

    ##! 2: 'build tmp file'
    # with UNLINK => 1 the file will be scheduled for deletion after the
    # file handle goes out of scope which is the end of this method!
    # this might lead to a race condition where the caller writes to the
    # file whereas the OS removes the file from the (visible) filesystem
    # The class will keep a list of files internally and remove those when
    # the I<cleanup> method is called
    my $fh = File::Temp->new( TEMPLATE => $template, UNLINK => 0 );
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

=head2  get_safe_tmpdir

Create an emtpty directory and returns its name. You can pass a hash with
the key I<TMP> set to the parent directory to use, if not set the
directory given to the constructor is used.

The directory will B<NEVER> be removed autmatically.

=cut

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

=head2 get_tmp_dirhandle

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


    my $tmpdir = $arg_ref->{TMP} || $temp_dir{$ident};

    ##! 2: 'check TMP'
    if (!$tmpdir) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_FILEUTILS_GET_SAFE_TEMPLATE_MISSING_TMP');
    }
    if (not -d $tmpdir) {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_FILEUTILS_GET_SAFE_TEMPLATE_DIR_DOES_NOT_EXIST',
            params => {DIR => $tmpdir});
    }

    ##! 2: 'build template'
    return File::Spec->catfile($tmpdir, "openxpki${PID}XXXXXXXX");
}

=head2 cleanup

Unlink files created with get_safe_tempfile and remove all handles
held by the instance so File::Temp should cleanup them.

B<Warning>: This method is not fork-safe and will delete any files
created with get_safe_tempfile across forks!

=cut

sub cleanup {

    my $self = shift;
    my $ident = ident $self;

    $temp_handles{$ident} = [];

    # when the KEEP_ALL marker is set we also do not run our cleanup
    return if ($File::Temp::KEEP_ALL);

    foreach my $file (keys %{$safe_filename_of{$ident}}) {
        if (-e $file) {
            unlink($file);
            delete $safe_filename_of{$ident}->{$file};
        }
    }

    return 1;
}

1;

__END__
