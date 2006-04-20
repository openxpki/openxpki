## OpenXPKI
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;
#use diagnostics;
use utf8;
#use encoding 'utf8';

package OpenXPKI;

use OpenXPKI::VERSION;
our $VERSION = $OpenXPKI::VERSION::VERSION;

use English qw (-no_match_vars);
use XSLoader;
XSLoader::load ("OpenXPKI", $VERSION);

use OpenXPKI::Exception;
use Date::Parse;
use DateTime;
use Scalar::Util qw( blessed );
use Locale::Messages qw (:locale_h :libintl_h nl_putenv);
use POSIX qw (setlocale);
use Fcntl qw (:DEFAULT);

use File::Spec;
use File::Temp;

our $language = "";
our $locale_prefix = "";

use vars qw (@ISA @EXPORT_OK);
require Exporter;
@ISA = qw (Exporter);
@EXPORT_OK = qw (i18nGettext set_locale_prefix set_language read_file write_file convert_date get_safe_tmpfile);

sub set_locale_prefix
{
    $locale_prefix = shift;
    if (not -e $locale_prefix)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SET_LOCALE_PREFIX_DIR_DOES_NOT_EXIST",
            params  => {"DIR" => $locale_prefix});
    }
}


sub i18nGettext {
    my $text = shift;

    my $arg_ref;
    my $ref_of_first_argument = ref($_[0]);

    # coerce arguments into a hashref
    if ($ref_of_first_argument eq "") {
	# first argument is a scalar
	my %arguments = @_;
	$arg_ref = \%arguments;
    } 
    elsif ($ref_of_first_argument eq "HASH") {
	$arg_ref = $_[0];
    }
    elsif ($ref_of_first_argument eq "REF") {
	$arg_ref = ${$_[0]};
    }

    ## we need this for utf8
    #it's too slow, I try to use "use utf8;"
    #my $i18n_string = pack "U0C*", unpack "C*", gettext ($text);
    my $i18n_string = gettext ($text);

    if ($i18n_string ne $text)
    {
	## there is a translation for this, so replace the parameters 
	## in the resulting string

	for my $parameter (keys %{$arg_ref}) {
	    warn if ($parameter !~ m{\A __\w+__ \z}xm);
            $i18n_string =~ s/$parameter/$arg_ref->{$parameter}/g;
        }
    } else {
        ## no translation found, output original string followed
	## by all parameters (and values) passed to the function

	## append arguments passed to the function
	my $untranslated .= join ("; ", 
				  $text,
				  map { $_ . " => " . $arg_ref->{$_}  } 
				      keys %{$arg_ref});
	
        #it's too slow, I try to use "use utf8;"
        #$i18n_string = pack "U0C*", unpack "C*", $untranslated;
    }

    return $i18n_string;
}



sub set_language
{
    ## global scope intended
    $language = shift;
    if (! defined $language) {
	$language = "";
    }

    ## erase environment to block libc's automatic environment detection
    ## and enforcement
    #delete $ENV{LC_MESSAGES};
    #delete $ENV{LC_TIME};
    delete $ENV{LANGUAGE};    ## known from Debian

    if ($language eq "C" or $language eq "")
    {
        setlocale(LC_MESSAGES, "C");
        setlocale(LC_TIME,     "C");
        nl_putenv("LC_MESSAGES=C");
        nl_putenv("LC_TIME=C");
    } else {
        my $loc = "${language}.UTF-8";
        setlocale(LC_MESSAGES, $loc);
        setlocale(LC_TIME,     $loc);
        nl_putenv("LC_MESSAGES=$loc");
        nl_putenv("LC_TIME=$loc");
    }
    textdomain("openxpki");
    bindtextdomain("openxpki", $locale_prefix);
    bind_textdomain_codeset("openxpki", "UTF-8");
}

sub read_file
{
    my $self     = shift;
    my $filename = shift;

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

    if ((-e $filename) && (! $keys->{FORCE}))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WRITE_FILE_ALREADY_EXISTS",
            params  => {"FILENAME" => $filename});
    }


    my $mode = O_WRONLY;
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

    ##! 1: "end: $filename"
    return $filename;
}

1;

__END__

=head1 Exported functions

Exported function are function which can be imported by every other
object. These function are exported to enforce a common behaviour of
all OpenXPKI modules for debugging and error handling.

C<use OpenXPKI::API qw (debug i18nGettext);>

=head2 debug

You should call the function in the following way:

C<$self-E<gt>debug ("help: $help");>

All other stuff is generated fully automatically by the debug function.


=head1 Description

This module manages all i18n stuff for the L<OpenCA::Server> daemon.
The main job is the implementation of the translation function and
the storage of the activated language.

All functions work in static mode (static member functions). 
This means that they are to be invoked directly and not via an object
instance.

=head1 Functions

=head2 set_locale_prefix

The only parameter is a directory in the filesystem. The function is used
to set the path to the directory with the mo databases.


=head2 i18nGettext

The first parameter is the i18n code string that should be looked up
in the translation table. Usually this identifier should look like
C<I18N_OPENCA_MODULE_FUNCTION_SPECIFIC_STUFF>. 
Optionally there may follow a hash or a hash reference that maps parameter
keywords to values that should be replaced in the original string.
A parameter should have the format C<__NAME__>, but in fact every
keyword is possible.

The function obtains the translation for the code string (if available)
and then replaces each parameter keyword in the code string
with the corresponding replacement value.

The function always returns an UTF8 string.

Examples:

    my $text;
    $text = i18nGettext("I18N_OPENCA_FOO_BAR");
    $text = i18nGettext("I18N_OPENCA_FOO_BAR", 
                        "__COUNT__" => 1,
                        "__ORDER__" => "descending",
                        );

    %translation = ( "__COUNT__" => 1,
                     "__ORDER__" => "descending" );
    $text = i18nGettext("I18N_OPENCA_FOO_BAR", %translation);

    $translation_ref = { "__COUNT__" => 1,
                         "__ORDER__" => "descending" };
    $text = i18nGettext("I18N_OPENCA_FOO_BAR", $translation_ref);



=head2 set_language

Switch complete language setup to the specified language. If no
language is specified then the default language C is activated. This
deactivates all translation databases.

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
