package OpenXPKI::i18n;
use strict;
use warnings;

# Core modules
use English;
use Locale::gettext_pp qw (:locale_h :libintl_h nl_putenv);
use POSIX qw (setlocale);
use Scalar::Util qw(blessed reftype refaddr);
use Memoize;

# Project modules
use OpenXPKI::Exception;
use OpenXPKI::Debug;


our $language = "";
our $locale_prefix = "";
our %_seen_refaddrs;

use vars qw (@ISA @EXPORT_OK);
use base qw( Exporter );
@EXPORT_OK = qw (i18nGettext i18nTokenizer i18n_walk set_locale_prefix set_language get_language);

sub set_locale_prefix {
    $locale_prefix = shift;
    if (not -e $locale_prefix) {
        OpenXPKI::Exception->throw(message => "Specified locale directory '$locale_prefix' does not exist");
    }
}

sub i18nGettext {
    my $text = shift;
    warn "Parameter expansion with i18nGettext() is no longer supported" if @_;

    # skip empty strings
    return unless $text;

    # translate
    my $translated = _i18n_gettext($text);

    # as we (hopefully) use i18nGettext() only to create internal strings
    # in preparation for a LATER output we decode this back to the
    # internal Perl format
    return Encode::decode('UTF-8', $translated);
}

sub _i18n_gettext {
    my $text = shift;

    # skip strings not starting with "I18N" - also fixes a problem with already
    # translated texts that include UTF-8 characters which break gettext().
    return $text unless $text =~ m{\AI18N_};

    # translate
    my $translated = gettext($text);

    # gettext does not support empty translations, we use a single whitespace which we dont want to show up.
    return '' if ($translated eq ' ');

    return $translated;
}

memoize('_i18n_gettext');

sub i18nTokenizer {
    my $text = shift;
    $text =~ s/(I18N_OPENXPKI_UI_[A-Z0-9a-z\_-]+)/_i18n_gettext($1)/ge;
    return $text;
}

sub i18n_walk {
    my $data = shift;
    die 'Parameter must be either HashRef or ArrayRef' unless (ref $data eq 'HASH' or ref $data eq 'ARRAY');

    local %_seen_refaddrs;
    return _walk($data);
}

# inspired by Data::Walk::More
sub _walk {
    my ($val) = @_; # $val may be Scalar, ArrayRef, HashRef etc.
    my $ref = ref $val;

    # Scalars: i18n translation
    if ($ref eq '') {
        my $translated = i18nTokenizer($val);
        # Note: we explicitely must "return undef" (not "return") or the
        # map{} function for HashRefs below will complain about
        # "Odd number of elements in anonymous hash"
        return undef unless defined $translated;
        # decode UTF-8 back to internal Perl format
        return Encode::decode('UTF-8', $translated);
    }

    # References: skip if already seen
    my $refaddr = refaddr($val);
    return $val if $_seen_refaddrs{$refaddr}++;

    if (blessed $val) {
        $ref = reftype($val);
    }

    # References: recurse if ArrayRef or HashRef
    return $val unless $ref eq 'ARRAY' || $ref eq 'HASH';

    if ($ref eq 'ARRAY') {
        return [ map { _walk($_) } @$val ];
    } else { # HASH
        return { map { $_ => _walk($val->{$_}) } keys %$val };
    }
}

sub set_language {
    ## global scope intended
    $language = shift || "C";

    ## erase environment to block libc's automatic environment detection
    ## and enforcement
    #delete $ENV{LC_MESSAGES};
    #delete $ENV{LC_TIME};
    delete $ENV{LANGUAGE};    ## known from Debian
    nl_putenv("LANGUAGE=$language");

    my $loc = $language eq "C" ? $language : "${language}.UTF-8";
    if (setlocale(LC_MESSAGES, $loc) ne $loc) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_I18N_SETLOCALE_LC_MESSAGES_FAILED',
            params  => { LOCALE => $loc },
        );
    };
    if (setlocale(LC_TIME, $loc) ne $loc) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_I18N_SETLOCALE_LC_TIME_FAILED',
            params  => { LOCALE => $loc },
        );
    }
    nl_putenv("LC_MESSAGES=$loc");
    nl_putenv("LC_TIME=$loc");

    textdomain("openxpki");
    bindtextdomain("openxpki", $locale_prefix);
    bind_textdomain_codeset("openxpki", "UTF-8");
}

sub get_language {
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

=head2 i18n_walk

Recurses into the given data structure (I<ArrayRef> or I<HashRef>) and
translates all occurrances if I18N strings in array items and hash values.

=head2 set_language

Switch complete language setup to the specified language. If no
language is specified then the default language C is activated. This
deactivates all translation databases.

=head2 get_language

returns the actually configured language.
