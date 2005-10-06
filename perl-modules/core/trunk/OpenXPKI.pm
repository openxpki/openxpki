## OpenXPKI
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
no warnings;

package OpenXPKI;

our $VERSION = sprintf "%d.%03d", q$Revision$ =~ /(\d+)/g;

use XSLoader;
XSLoader::load ("OpenXPKI", $VERSION);

use Date::Parse;
use Locale::Messages qw (:locale_h :libintl_h);
use POSIX qw (setlocale);
use Fcntl qw(:DEFAULT);

our $language;
our $prefix;

use vars qw(@ISA @EXPORT_OK);
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(i18nGettext set_language get_language debug set_error errno errval read_file write_file);

=head1 Exported functions

Exported function are function which can be imported by every other
object. These function are exported to enforce a common behaviour of
all OpenXPKI modules for debugging and error handling.

C<use OpenXPKI::API qw (debug i18nGettext set_error errno errval);>

=head2 debug

You have only to call the function in the following way:

C<$self-E<gt>debug ("help: $help");>

All other stuff is generated fully automatically by the debug function.

=cut

sub debug
{
    my $self     = shift;
    return 1 if (not ref ($self) or not $self->{DEBUG});
    my $msg      = shift;

    my ($package, $filename, $line, $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(0);
    $msg = "(line $line): $msg";

    ($package, $filename, $line, $subroutine, $hasargs,
     $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);
    $msg = "$subroutine $msg\n";

    #debugging output in syslog facilities is hard to read and a real flood
    #if ($self->{api} and ref $self->{api})
    #{
    #    $self->{api}->log (FACILITY => "system",
    #                       PRIORITY => "debug",
    #                       MESSAGE  => $msg);
    #} else {
        print STDERR $msg;
    #}
}

=head2 set_error

The error setting function supports four different types of parameter
handling. This is necessary to support old module or modules which do
not define errorcodes.

An error name is C<I18N_OPENXPKI_MODULE_FUNCTION_ERROR>.

Please note that we alway add the two parameters __OLD_ERRNO__ and
__OLD_ERRVAL__ if we detect an old error. If the translator expect
such stuff then you can display all errors. Otherwise you can see
all errors if you deactivate all specific languages (LC_MESSAGES=C).

If an error name is not translated (this is the case if the translation
function returns the error name) then we take the error name and
join it with all parameter/value pairs.

=over

=item 1. %ERRHASH exists for the module

If the function has a global static hash ERRHASH then the function
assumes the error name first followed by the parameter pairs. Example:

C<$self-E<gt>set_error ("I18N_OPENXPKI_AC_CHECK_IDENT_USER_UNKNOWN", "__USER__" =E<gt> $user);>

=item 2. direct error setting

The second method is direct error setting. If you do not like to
maintain a hash of errorcodes then you can set the error code directly
followed by the error name and the parameters. Example:

C<$self-E<gt>set_error (123456, "I18N_OPENXPKI_AC_CHECK_IDENT_USER_UNKNOWN", "__USER__" =E<gt> $user);>

=item 3. forgotten %ERRHASH

Sometimes you forgot to define errorcodes or you do not want to define
errorcodes. We support in this case the same interface like for the
first version. The errno is in this case always -1.

=back

=cut

sub set_error
{
    my $self = shift;
    my $code = shift;

    if (not ref $self)
    {
        my $ref = {};
        bless $ref, $self;
        $self = $ref;
    }

    my ($package, $filename, $line, $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(0);

    $self->debug ("package: $package");
    $self->debug ("code:    $code");
    my $name = $package."::ERRHASH";
    my %hash = eval "\%${name}";

    my $new_errno;
    if ($hash{$code}) {
        $self->debug ("1. method");
        $new_errno = $hash{$code};
    } elsif ($code =~ /^I18N_OPENXPKI_/ or not scalar @_) {
        $self->debug ("3. method");
        $new_errno = -1;
    } else {
        $self->debug ("2. method");
        $new_errno = $code;
    }

    if ($new_errno == $code)
    {
        $self->debug ("parameter shift for 2. method");
        $code = shift;
    }

    # deactivated error saving because it creates a lot of confusion
    # bellmich 2005-jul-05
    #if ($self->{errno})
    #{
    #    $self->{errval} = i18nGettext ($code, @_,
    #                                   "__OLD_ERRVAL__", $self->{errval},
    #                                   "__OLD_ERRNO__",  $self->{errno});
    #} else {
        $self->{errval} = i18nGettext ($code, @_);
    #}
    $self->{errval} = join ", ", $code, @_ if ($self->{errval} eq $code);

    $self->{errno} = $new_errno;

    $name = $package."::errno";
    eval "\$$name = \$self->{errno};";
    $name = $package."::errval";
    eval "\$$name = \$self->{errval};";

    $self->debug ("$self->{errno}: $self->{errval}");
    return undef;
}

=head2 errno

returns the actual error number of this object instance.

=cut

sub errno
{
    my $self = shift;
    return $self->{errno} if (ref($self));
    return eval ("\$".$self."::errno");
}

=head2 errval

returns the actual error string of this object instance.

=cut

sub errval
{
    my $self = shift;
    return $self->{errval} if (ref($self));
    return eval ("\$".$self."::errval");
}

=pod

=head1 Description

This module manages all i18n stuff for the L<OpenCA::Server> daemon.
The main job is the implementation of the translation function and
the storage of the activated language.

All functions work in static mode. This means that we do not use object
instances or something like this.

=head1 Functions

=head2 set_prefix

Only parameter is a directory in the filesystem. The function is used
to set the path to the directory with the mo databases.

=cut

sub set_prefix
{
    $prefix = shift;
}

=pod

=head2 i18nGettext

The first parameter is the i18n code string. Usually it looks like
C<I18N_OPENCA_MODULE_FUNCTION_SPECIFIC_STUFF>. The rest is a hash
with parameter value pairs. A parameter should look like C<__NAME__>.
A value can be every textstring. The function loads the translation for
the code string and then it replaces the parameters in the code string
with the specified values.

Only UTF8 strings are returned.

=cut

sub i18nGettext {

    ## we need this for utf8
    my $i18n_string = pack "U0C*", unpack "C*", gettext ($_[0]);
    if ($i18n_string ne $_[0])
    {
        my $i = 1;
        my $option;
        my $value;
        while ($_[$i]) {
            $i18n_string =~ s/$_[$i]/$_[$i+1]/g;
            $i += 2;
        }
    } else {
        ## missing translations should not drop the parameters
        $i18n_string = pack "U0C*", unpack "C*", join ', ', @_;
    }

    return $i18n_string;
}

=pod

=head2 set_language

configure the complete language stuff to the specified language. If no
language is specified then we activate the default language C. This
deactivates all translation databases.

=cut

sub set_language
{
    $language = $_[0];

    ## erase environment to block libc's automatic environment detection
    ## and enforcement
    #delete $ENV{LC_MESSAGES};
    #delete $ENV{LC_TIME};
    delete $ENV{LANGUAGE};    ## known from Debian

    my $old = "-";
    if ($language eq "C" or $language eq "")
    {
        setlocale(LC_MESSAGES, "C");
        setlocale(LC_TIME,     "C");
    } else {
        setlocale(LC_MESSAGES, "${language}.UTF-8");
        setlocale(LC_TIME,     "${language}.UTF-8");
    }
    textdomain("openxpki");
    bindtextdomain("openxpki", $prefix);
    bind_textdomain_codeset ("openxpki", "UTF-8");
}

=pod

=head2 get_language

returns the actually active language.

=cut

sub get_language
{
    return $language;
}

=head1 File functionality

=head2 read_file

Example: $self->read_file($filename);

=cut

sub read_file
{
    my $self     = shift;
    my $filename = shift;

    if (not -e $filename)
    {
        $self->set_error ("I18N_OPENXPKI_READ_FILE_NOT_EXIST",
                          "__FILENAME__", $filename);
        return undef;
    }

    if (not open (FD, $filename))
    {
        $self->set_error ("I18N_OPENXPKI_READ_FILE_OPEN_FAILED",
                          "__FILENAME__", $filename);
        return undef;
    }

    my $result = "";
    while ( <FD> )
    {
        $result .= $_;
    }
    close(FD);

    return $result;
}

=head2 write_file

Example: $self->write_file (FILENAME => $filename, CONTENT => $data);

=cut

sub write_file
{
    my $self     = shift;
    my $keys     = { @_ };
    my $filename = $keys->{FILENAME};
    my $content  = $keys->{CONTENT};

    if (-e $filename)
    {
        $self->set_error ("I18N_OPENXPKI_WRITE_FILE_ALREADY_EXIST",
                          "__FILENAME__", $filename);
        return undef;
    }

    if (not sysopen(FD, $filename, O_WRONLY | O_EXCL | O_CREAT))
    {
        $self->set_error ("I18N_OPENXPKI_WRITE_FILE_OPEN_FAILED",
                          "__FILENAME__", $filename);
        return undef;
    }
    print FD $content;
    close FD;

    return 1;
}

1;
