## OpenXPKI
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
no warnings;

package OpenXPKI;

our $VERSION = sprintf "0.9.3.%03d", q$Revision$ =~ /(\d+)/g;

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
@EXPORT_OK = qw(i18nGettext set_language get_language debug read_file write_file);

=head1 Exported functions

Exported function are function which can be imported by every other
object. These function are exported to enforce a common behaviour of
all OpenXPKI modules for debugging and error handling.

C<use OpenXPKI::API qw (debug i18nGettext);>

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
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_READ_FILE_NOT_EXIST",
            params  => {"FILENAME" => $filename});
    }

    if (not open (FD, $filename))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_READ_FILE_OPEN_FAILED",
            params  => {"FILENAME" => $filename});
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
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WRITE_FILE_ALREADY_EXIST",
            params  => {"FILENAME" => $filename});
    }

    if (not sysopen(FD, $filename, O_WRONLY | O_EXCL | O_CREAT))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WRITE_FILE_OPEN_FAILED",
            params  => {"FILENAME" => $filename});
    }
    print FD $content;
    close FD;

    return 1;
}

1;
