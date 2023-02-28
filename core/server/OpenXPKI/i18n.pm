## OpenXPKI::i18n.pm
## Written 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2005-2006 The OpenXPKI Project

use strict;
use warnings;
use utf8;

package OpenXPKI::i18n;

use English;

use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Locale::gettext_pp qw (:locale_h :libintl_h nl_putenv);
use POSIX qw (setlocale);

our $language = "";
our $locale_prefix = "";

use vars qw (@ISA @EXPORT_OK);
use base qw( Exporter );
#require Exporter;
#@ISA = qw (Exporter);
@EXPORT_OK = qw (i18nGettext i18nTokenizer set_locale_prefix set_language get_language);

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

    # do not handle empty strings or strings that do not start with I18N...
    # this also fixes a problem with already translated texts having utf8
    # characters as they break when handled by gettext
    return $text unless (defined $text && length($text) && $text =~ m{\AI18N_});

    warn "Parameter expansion with i18nGettext is no longer supported" if (@_);

    my $i18n_string = gettext($text);

    # gettext does not support empty translations, we use a single whitespace which we dont want to show up.
    return '' if ($i18n_string eq ' ');

    # as we use this (hopefully) only to create internal strings
    # in preparation for a LATER output we decode this back to the
    # perl internal format
    return Encode::decode('UTF-8', $i18n_string);
}

sub i18nTokenizer {

    my $string = shift;
    my %tokens = map { $_ => '' } ($string =~ /(I18N_OPENXPKI_UI_[A-Z0-9a-z\_-]+)/g);
    foreach my $token (keys %tokens) {
        my $replace = gettext($token);
        $replace = '' if ($replace eq ' ');
        $string =~ s/$token\b/$replace/g;
    }
    return $string;

}

sub set_language
{
    ## global scope intended
    $language = shift || "C";

    ## erase environment to block libc's automatic environment detection
    ## and enforcement
    #delete $ENV{LC_MESSAGES};
    #delete $ENV{LC_TIME};
    delete $ENV{LANGUAGE};    ## known from Debian
    nl_putenv("LANGUAGE=$language");
    if ($language eq "C") {
        setlocale(LC_MESSAGES, "C");
        setlocale(LC_TIME,     "C");
        nl_putenv("LC_MESSAGES=C");
        nl_putenv("LC_TIME=C");
    } else {
        my $loc = "${language}.UTF-8";
        if (setlocale(LC_MESSAGES, $loc) ne $loc) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_I18N_SETLOCALE_LC_MESSAGES_FAILED',
                params  => {
                    LOCALE => $loc,
                },
            );
        };
        if (setlocale(LC_TIME,     $loc) ne $loc) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_I18N_SETLOCALE_LC_TIME_FAILED',
                params  => {
                    LOCALE => $loc,
                },
            );
        }
        nl_putenv("LC_MESSAGES=$loc");
        nl_putenv("LC_TIME=$loc");
    }
    textdomain("openxpki");
    bindtextdomain("openxpki", $locale_prefix);
    bind_textdomain_codeset("openxpki", "UTF-8");
}

sub get_language
{
    return $language;
}

1;

__END__

=head1 Name

OpenXPKI::i18n - internationalization (i18n) handling class.

=head1 Exported functions

Exported function are function which can be imported by every other
object. All i18n functions are static functions and work in global
context.

=head1 Description

This module manages all i18n stuff for the L<OpenXPKi> system.
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

Returns the translation for a string based on the current gettext settings.
It will handle the internal convention of the "empty string" being a single
whitespace to disable certain translations and return a real empty string
instead.

The resulting string can contain UTF8 characters and is encoded with the
perl internal representation so it should be safe to work with it inside
perl. If you want to output the string directly you might need to call
Encode::encode('UTF-8') or similar on the result.

If the string does not start with the prefix I<I18N_OPENXPKI_UI>, the method
just returns the input as is.

=head2 i18nTokenizer

Expects a string that contains translatable items I<I18N_OPENXPKI_UI> and
replaces any occurence with its translation. The result is returned with
"external utf-8" encoding so it should be directly echoed.

=head2 set_language

Switch complete language setup to the specified language. If no
language is specified then the default language C is activated. This
deactivates all translation databases.

=head2 get_language

returns the actually configured language.
