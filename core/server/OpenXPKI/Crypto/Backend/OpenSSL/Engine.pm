## OpenXPKI::Crypto::Backend::OpenSSL::Engine 
## Copyright (C) 2003-2005 Michael Bell

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Engine;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use English;
use OpenXPKI::Server::Context qw( CTX );

use Data::Dumper;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    my $keys = { @_ };

    bless ($self, $class);
    ##! 2: "new: class instantiated"

    ## token mode will be ignored
    foreach my $key (qw{OPENSSL
                        NAME
                        KEY
                        PASSWD
                        SECRET
                        CERT
                        INTERNAL_CHAIN
                        ENGINE_SECTION
                        ENGINE_USAGE
                        KEY_STORE
                       }) {

	if (exists $keys->{$key}) {
            ##! 128: 'setting key ' . $key . ' to value ' . Dumper $keys->{$key}
	    $self->{$key} = $keys->{$key};
	}
    }
    $self->__check_engine_usage();
    $self->__check_key_store();
    
    return $self;
}

sub __check_engine_usage {
    my $self = shift;
    my @engine_usage_parts = split (m{\|}, $self->{ENGINE_USAGE});

    # if ENGINE_USAGE is defined
    if ($#{engine_usage_parts} >= 0) {
        foreach my $part(@engine_usage_parts) {
            if ($part !~ m{( \A ALWAYS \z )|( \A NEVER \z )|( \A NEW_ALG \z )|( \A PRIV_KEY_OPS \z )|( \A RANDOM \z ) }xms) {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_WRONG_ENGINE_USAGE",
                    params  => { "ATTRIBUTE" => $part},   
                    );
            }
            # if NEVER is not the only one value
            if (($part =~ m{ \A NEVER \z }xms) and 
                ($#{engine_usage_parts} >= 1)) {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_WRONG_NEVER_ENGINE_USAGE" );
            } # if NEVER is not the only one value
        } # foreach $part
    } # if ENGINE_USAGE is defined

    return 1;
}

sub __check_key_store {
    my $self = shift;
    if ($self->{KEY_STORE} !~ m{( \A ENGINE \z )|( \A OPENXPKI \z ) }xms) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_WRONG_KEY_STORE",
            params  => { "ATTRIBUTE" => $self->{KEY_STORE}},
            );
    }

    return 1;
}

sub login {
    my $self = shift;
    my $keys = shift;

    ## check the supplied parameter
    if (not $self->{SECRET}->is_complete())
    {
        ## enforce passphrases
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_OPENSSL_LOGIN_INCOMPLETE_SECRET");
    }
    $self->{PASSWD} = $self->{SECRET}->get_secret();
    if (length $self->{PASSWD} < 4)
    {
        ## enforce OpenSSL default passphrase length
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_OPENSSL_LOGIN_PASSWD_TOO_SHORT");
    }

    ## test the passphrase
    eval
    {
        # this is probably broken
        $self->{OPENSSL}->command ({COMMAND => "convert_key", OUTFORM=>"PKCS8"});
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_OPENSSL_LOGIN_FAILED");
    } elsif ($EVAL_ERROR) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_OPENSSL_LOGIN_FAILED_EVAL_ERROR",
	    params => {
		EVAL_ERROR => $EVAL_ERROR,
	    },
	);
    }

    $self->{ONLINE} = 1;
    return 1;
}

sub logout {
    my $self = shift;
    delete $self->{PASSWD};
    $self->{ONLINE} = 0;
    return 1;
}

sub online {
    my $self = shift;
    return 1;
}

#sub key_usable {
#    my $self = shift;
#    return 0 if (not $self->{ONLINE});
#    return 1;
#}

sub get_engine
{
    return "";
}

sub get_engine_section
{
    my $self = shift;

    if (length ($self->get_engine()) and
        exists $self->{ENGINE_SECTION} and
        length ($self->{ENGINE_SECTION}))
    {
        return $self->{ENGINE_SECTION};
    } else {
        return "";
    }
}

sub get_engine_usage
{
    my $self = shift;

    if (length ($self->get_engine()) and
        exists $self->{ENGINE_USAGE} and
        length ($self->{ENGINE_USAGE}))
    {
        return $self->{ENGINE_USAGE};
    } else {
        return "";
    }
}

sub get_key_store
{
    my $self = shift;
    return $self->{KEY_STORE};
}

sub get_keyfile
{
    my $self = shift;
    return $self->{KEY};
}

sub get_passwd
{
    ##! 16: 'start'
    my $self = shift;

    if (defined $self->{SECRET} && $self->{SECRET}->is_complete()) {
	##! 16: 'secret is_complete: ' . $self->{SECRET}->is_complete()
	return $self->{SECRET}->get_secret();
    }

    return $self->{PASSWD} if (exists $self->{PASSWD});
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_GET_PASSWD_UNDEF");
}

sub get_certfile
{
    my $self = shift;
    return $self->{CERT};
}

sub get_chainfile
{
    my $self = shift;
    return $self->{INTERNAL_CHAIN};
}

sub get_keyform
{
    ## do not return something with a leading "e"
    ## if you don't use an engine
    return "";
}

sub get_wrapper
{
    return "";
}

sub get_engine_params
{
    return "";
}

sub filter_stderr
{
    my $self = shift;
    return $_[0];
}

sub filter_stdout
{
    my $self = shift;
    return $_[0];
}

sub key_usable {
    my $self = shift;

    eval {
        $self->get_passwd();
    };
    if ($EVAL_ERROR) {
        # we could not get the password, so the key is not usable
        return 0;
    }
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Engine

=head1 Description

This class is the base class and the interface of all other engines.
This defines the interface how HSMs are supported by OpenXPKI.

=head1 Functions

=head2 new

The constructor supports the following parameters:

=over

=item * OPENSSL (the OpenSSL binary)

=item * NAME (a symbolic name for the token)

=item * KEY (filename of the key)

=item * PASSWD (sometimes keys are passphrase protected)

=item * CERT (filename of the certificate)

=item * INTERNAL_CHAIN (filename of the certificate chain)

=back

=head2 login

tries to set the passphrase for the used token and checks the passphrase for its
correctness. If the passhrase is missing, shorter than 4 characters or
simply wrong then an exception is thrown. There is no parameters because
we get the passphrase from the OpenXPKI::Crypto::Secret object.

Examples: $engine->login ();

=head2 logout

enforces the logout form the token.

=head2 online

returns true if the token is usable for non-pivate-key
operations.

=head2 key_usable

returns true if the private key is usable.

=head2 get_mode

returns the operational mode of the engine (standby, session or daemon).

=head2 get_engine

returns the used OpenSSL engine or the empty string if no engine
is used.

=head2 get_engine_section

returns the OpenSSL engine section from the configuration or the empty string if no engine
is used or the engine section is empty.

=head2 get_engine_usage
 
returns the OpenSSL engine_usage section from the configuration or the empty string if no engine
is used or the engine_usage section is empty.

=head2 get_key_store
 
returns the OpenSSL key_store section from the configuration.

=head2 get_keyfile

returns the filename of the private key.

=head2 get_passwd

returns the passphrase if one is present.

=head2 get_certfile

returns the filename of the certificate.

=head2 get_chainfile

returns the filename of the internal (CA specific) certificate chain.

=head2 get_keyform

returns "e" or "engine" if the key is stored in an OpenSSL engine.

=head2 get_wrapper

returns the wrapper around the OpenSSL binary if such a
wrapper is used (e.g. nCipher's chil engine). Otherwise the empty string
is returned.

=head2 get_engine_params

returns the parameters for the engine which are needed for the
initialization. This is a simple string.

=head2 filter_stderr

expects a scalar with the complete error log inside. It returns
the error log but without all normal stuff which is generated by
the used engine. The function is used to filter false error
messages from STDERR.

=head2 filter_stdout

expects a scalar with the complete output inside. It returns
the output but without the noise which is generated by
the used engine. The function is used to filter engine specific
messages from STDOUT.

