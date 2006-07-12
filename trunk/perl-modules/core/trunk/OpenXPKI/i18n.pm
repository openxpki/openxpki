## OpenXPKI::i18n.pm
## Written 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2005-2006 The OpenXPKI Project
## $Revision: 240 $

use strict;
use warnings;
use utf8;

package OpenXPKI::i18n;

use English;

use OpenXPKI::Exception;
use Locale::Messages qw (:locale_h :libintl_h nl_putenv);
use POSIX qw (setlocale);

our $language = "";
our $locale_prefix = "";

use vars qw (@ISA @EXPORT_OK);
use base qw( Exporter );
#require Exporter;
#@ISA = qw (Exporter);
@EXPORT_OK = qw (i18nGettext set_locale_prefix set_language);

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
        $i18n_string = join ("; ", $text,
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

1;

__END__

=head1 Name

OpenXPKI::i18n - internationalization (i18n) handling class.

=head1 Exported functions

Exported function are function which can be imported by every other
object. All i18n functions are static functions and work in global
context.

=head2 debug

You should call the function in the following way:

i18nGettext ("I18N_OPENXPKI_MY_CLASS_MY_FUNCTION_MY_MESSAGE");>

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
