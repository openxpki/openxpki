## OpenXPKI::Crypto::Backend::OpenSSL::Engine::nCipher 
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## Extended 2008 by Martin Bartosch for the OpenXPKI project
##   - added HSM and key online tests
## (C) Copyright 2005-2008 by The OpenXPKI Project
##
## This driver supports nCipher nShield HSMs using HWCRHK keys that are
## preloaded using 'with-nfast pause' or 'preload pause'.
##
## Successfully tested with the following versions  (as reported by 
## /opt/nfast/bin/enquiry):
## nShield modules
##   nC1002W/nC3022W/nC4032W (version 2.18.13)
##   nC1003P/nC3023P/nC3033P (version 2.33.82)
## hardserver
##   2.15.15cam4, 2.18.13cam1 built on Jun 28 2004 15:26:25
##   2.36.16cam18, 2.33.82cam1 built on Mar 06 2008 15:55:03
## 
## Other versions (in particular such between the tested ones) may work.
##

package OpenXPKI::Crypto::Backend::OpenSSL::Engine::nCipher;

use strict;
use warnings;
use English;
use Data::Dumper;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Engine);
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use Memoize;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    my $keys = { @_ };

    bless ($self, $class);
    ##! 2: "new: class instantiated"

    # defaults
    $self->{NFAST_HOME} = '/opt/nfast';
    $self->{CHECKCMDTIMEOUT} = 25;
    $self->{ONLINECHECKGRACEPERIOD} = 60;

    ## token mode will be ignored
    foreach my $key (qw( 
        OPENSSL
        NAME
        KEY
        PASSWD
        SECRET
        CERT
        INTERNAL_CHAIN
        ENGINE_SECTION
        ENGINE_USAGE
	KEY_STORE
	WRAPPER
        NFAST_HOME
        CHECKCMDTIMEOUT
        ONLINECHECKGRACEPERIOD
    ) ) {
        if (exists $keys->{$key}) {
            $self->{$key} = $keys->{$key};
        }
    }
    $self->__check_engine_usage();
    $self->__check_key_store();

    if (! -d $self->{NFAST_HOME} || ! -x $self->{NFAST_HOME}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_NFAST_HOME_NOT_ACCESSIBLE",
            params  => { 
		NFAST_HOME => $self->{NFAST_HOME},
	    },
            );
    }

    foreach my $entry (qw( CHECKCMDTIMEOUT ONLINECHECKGRACEPERIOD )) {
	if (! defined $self->{$entry} 
	    || ($self->{$entry} !~ m{ \A \d+ \z }xms)) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_INVALID_VALUE",
		params  => {
		    PARAMETER => $entry,
		    VALUE     => $self->{$entry},
		},
		);
	}
    }

    return $self;
}

sub get_engine
{
    return 'chil';
}

sub get_keyform
{
    ## do not return something with a leading "e"
    ## if you don't use an engine
    return 'engine';
}

sub get_wrapper
{
    my $self = shift;
    return $self->{WRAPPER};
}

# FIXME - find a suitable replacement
sub cachestatus {
    my $self = shift;
    return;
}

# check if the token key is available
sub key_usable {
    my $self = shift;
    
    ##! 1: "nCipher HSM key online check"

    # if the last check was performed successfully within our grace period
    # simply return the cached result
    if ($self->cachestatus(
	    {
		ID => 'key_' . $self->{KEY},
		TIMEOUT => $self->{ONLINECHECKGRACEPERIOD},
		RETRIGGER => 1,
	    })) {
	##! 2: "Last key online check was performed less than " . $self->{ONLINECHECKGRACEPERIOD} . " seconds ago. Returning cached result."
	return 1;
    }
    
    # check security world and get information about preloaded objects
    my @cmd = ($self->{WRAPPER},
		"$self->{NFAST_HOME}/bin/nfkminfo");

    my $section = '';
    my $worldinfo;
    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
	alarm $self->{CHECKCMDTIMEOUT};

	##! 4: "keyOnline: exec: " . join (' ', @cmd)
	my $handle;
	if (! open $handle, join (' ', @cmd) . "|") {
	    ##! 4: "nCipher nfkminfo: could not run command '" . join (' ', @cmd) . "'"
	    alarm 0;
	    OpenXPKI::Exception->throw(
		message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_KEY_USABLE_EXEC_NFKMINFO_COMMAND_ERROR",
		params  => { 
		    EVAL_ERROR => $EVAL_ERROR,
		},
		);
	}
	
	# parse nfkminfo output
	while (<$handle>) {
	    chomp;
	    if (m{ \A \S }xms) {
		s{ [: \#\-] }{}xmsg;
		$section = lc($_);
		##! 8: "section: $section"
	    } else {
		if (($section ne '')
		    && (m{ \A \s+ (state) \s \s+ (.*) }xms)) {
		    ##! 8: "property key: $1, value: $2"
		    $worldinfo->{$section}->{lc($1)} = $2;
		}
		if ($section =~ m{ \A preloadedobjects }xms) {
		    m{ \s+ ([0-9A-Fa-f]+) }xms;
		    ##! 8: "hash: $1"
		    $worldinfo->{preloadedobjects}->{$1}++;
		}
	    }
	}
	close $handle;
	alarm 0;
    };

    # handle exceptions
    if ($EVAL_ERROR) {
        alarm 0;
	if ($EVAL_ERROR ne "alarm\n") {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_KEY_USABLE_COMMAND_INVOCATION_UNEXPECTED_EXCEPTION",
		params  => { 
		    EVAL_ERROR => $EVAL_ERROR,
		},
		);
	}
        ##! 4: "nCipher nfkminfo did not terminate within timeout and was interrupted administratively"
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_KEY_USABLE_COMMAND_INVOCATION_TIMEOUT",
	    params  => { 
	    },
	    );
    }
    
    if ($CHILD_ERROR != 0) {
	##! 4: "nCipher nfkminfo returned error code $CHILD_ERROR"
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_KEY_USABLE_COMMAND_INVOCATION_ERROR",
	    params  => { 
		CHILD_ERROR => $CHILD_ERROR,
	    },
	    );
    }

    ##! 4: "nCipher security world information"
    ##! 4: "  state:" . $worldinfo->{world}->{state}
    my $initialized = 0;
    my $usable = 0;
    foreach (split(m{ \s+ }xms, $worldinfo->{world}->{state})) {
	$initialized++ if ($_ eq 'Initialised');
	$usable++ if ($_ eq 'Usable');
    }

    if (! $initialized) {
	##! 4: "security world is not initialized"
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_KEY_USABLE_SECURITY_WORLD_NOT_INITIALIZED",
	    params  => { 
	    },
	    );
    }
    if (! $usable) {
	##! 4: "security world is not usable"
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_KEY_USABLE_SECURITY_WORLD_NOT_USABLE",
	    params  => { 
	    },
	    );
    }

    if (! exists $worldinfo->{preloadedobjects}) {
	##! 4: "no preloaded objects found"
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_KEY_USABLE_NO_PRELOADED_OBJECTS_FOUND",
	    params  => { 
	    },
	    );
    }

    ##! 2: "preloaded objects:"
    foreach (keys %{$worldinfo->{preloadedobjects}}) {
	##! 2: "  $_"
    } 

    # now we have got a list of preloaded objects. verify it against
    # the object hash of the desired private key.
    # so first find out what the hash of the key is.

    my $ocshash = $self->__getKeyHash();
    ##! 1: "verify if key ocs object hash $ocshash is preloaded"
    if (! exists $worldinfo->{preloadedobjects}->{$ocshash}) {
	##! 1: "object is not preloaded, key is not usable"
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_KEY_USABLE_OBJECT_NOT_PRELOADED",
	    params  => {
		OCSHASH => $ocshash,
	    },
	    );
    }
    ##! 1: "key seems to be usable"

    # remember key online status
    $self->cachestatus(ID => 'key_' . $self->{KEY});

    return 1;
}

sub login {
    my $self = shift;

    $self->{ONLINE} = 1;
    return 1;
}

sub get_passwd
{
    ##! 16: 'start'
    my $self = shift;

    return;
}


# check if HSM is attached, online and hardserver process is running
# the following tests are performed:
# - hardserver daemon is running and reports that nCipher is operational
# - at least one nCipher module is online
sub online {
    my $self = shift;
    ##! 1: "nCipher HSM online check"

    # if the last check was performed successfully within our grace period
    # simply return the cached result
    if ($self->cachestatus(
	    {
		ID        => 'ncipher_module',
		TIMEOUT   => $self->{ONLINECHECKGRACEPERIOD},
		RETRIGGER => 1,
	    })) {
	##! 2: "Last HSM online check was performed less than " . $self->{ONLINECHECKGRACEPERIOD} . " seconds ago. Returning cached result."
	return 1;
    }

    ##! 2: "Checking nCipher infrastructure"

    # call enquiry to collect information for hardserver and attached modules
    my $section = '';
    my $enquiry;
    my @modules;

    eval {
	local $SIG{ALRM} = sub { die "alarm\n" };
	alarm $self->{CHECKCMDTIMEOUT};
	
	my @cmd = (
	    qq("$self->{NFAST_HOME}/bin/enquiry"),
	    );

	my $cmd = join(' ', @cmd);

	##! 4: "exec: $cmd"
	my $handle;
	if (! open $handle, $cmd . '|') {
	    alarm 0;
	    ##! 4: "nCipher enquiry: could not run command '$cmd'"
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_ONLINE_COMMAND_INVOCATION_FAILED",
		params  => { 
		    COMMAND => $cmd,
		},
		);
	}
	
	# parse enquiry output
	while (my $line = <$handle>) {
	    chomp $line;
	    if ($line =~ m{ \A \S }xms) {
		$line =~ s{ [: \#] }{}xms;
		
		$section = lc($line);
		##! 4: "   section: $section"
		if ($section =~ m{ \A module }xms) {
		    push (@modules, $section);
		}
	    } else {
		if (($section ne '')
		    && ($line =~ m{ \A \s+ (mode|version) \s\s+ (\S+) }xms)) {
		    ##! 4: "     property: $1, value: $2"
		    $enquiry->{$section}->{lc($1)} = $2;
		}
	    }
	}
	close $handle;
	alarm 0;
    };

    # handle exceptions
    if ($EVAL_ERROR) {
        alarm 0;
	if ($EVAL_ERROR ne "alarm\n") {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_ONLINE_COMMAND_INVOCATION_UNEXPECTED_EXCEPTION",
		params  => { 
		    EVAL_ERROR => $EVAL_ERROR,
		},
		);
	}

        ##! 4: "nCipher enquiry did not terminate within timeout and was interrupted administratively"
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_ONLINE_COMMAND_INVOCATION_TIMEOUT",
	    params  => { 
	    },
	    );
    }

    if ($CHILD_ERROR != 0) {
	##! 4: "nCipher enquiry: hardserver is not running (error code $CHILD_ERROR)"
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_ONLINE_COMMAND_INVOCATION_ERROR",
	    params  => { 
		CHILD_ERROR => $CHILD_ERROR,
	    },
	    );
    }

    ##! 64: 'enquiry: ' . Dumper $enquiry
    ##! 64: 'modules: ' . Dumper \@modules

    ##! 4: "nCipher hardserver information"
    my $operational_modules = 0;
    foreach my $entry ('server', @modules) {
	##! 1: "   '$entry' (version: $enquiry->{$entry}->{version}) is $enquiry->{server}->{mode}"
	if (($entry ne 'server') 
	    && ($enquiry->{$entry}->{mode} eq 'operational')) { 
	    $operational_modules++;
	}
    }
    
    if ($enquiry->{server}->{mode} ne 'operational') {
	##! 1: "nCipher hardserver process is not operational."
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_ONLINE_HARDSERVER_NOT_OPERATIONAL",
	    params  => { 
	    },
	    );
    }
    ##! 4: 'nCipher hardserver process is operational'
    ##! 4: "number of operational nCipher modules: $operational_modules"
    
    if ($operational_modules < 1) {
	##! 1: "No operational nCipher modules are online."
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_ONLINE_NO_OPERATIONAL_MODULES_ONLINE",
	    params  => { 
	    },
	    );
     }

    $self->cachestatus(ID => 'ncipher_module');

    return 1;
}


# get object hash for our private key
# ret: object hash value of the private key for this token
#      undef on error
sub __getKeyHash {
    my $self = shift;

    ##! "get object hash for private key " . $self->{KEY}
    my @cmd = (
	qq("$self->{NFAST_HOME}/bin/nfkminfo"),
	'-k',
	'hwcrhk',
	qq("$self->{KEY}"),
	);

    my $keyhash;
    eval {
	local $SIG{ALRM} = sub { die "alarm\n" };
	alarm $self->{CHECKCMDTIMEOUT};

	# call nfkmverify to get object hash for key
	my $cmd = join (' ', @cmd);
	##! 2: "exec: $cmd"
	my $handle;
	if (! open $handle, $cmd . '|') {
	    alarm 0;
            ##! 4: "nCipher nfkminfo: could not run command '$cmd'"
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_GETKEYHASH_COMMAND_INVOCATION_FAILED",
		params  => { 
		    COMMAND => $cmd,
		},
		);
	}
	
	# parse nfkminfo output
      INFO:
	while (<$handle>) {
	    chomp;
	    if (m{ \A \s* hash \s+ (.*) }xms) {
		$keyhash = $1;
		last INFO;
	    }
        }
        close $handle;

	alarm 0;
    };
    # handle exceptions
    if ($EVAL_ERROR) {
        alarm 0;
	if ($EVAL_ERROR ne "alarm\n") {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_GETKEYHASH_COMMAND_INVOCATION_UNEXPECTED_EXCEPTION",
		params  => { 
		    EVAL_ERROR => $EVAL_ERROR,
		},
		);
	}
	##! 2: "nCipher nfkmverify did not terminate within timeout and was interrupted administratively"
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_GETKEYHASH_COMMAND_INVOCATION_TIMEOUT",
	    params  => { 
	    },
	    );
    }

    if ($CHILD_ERROR != 0) {
        ##! 2: "nCipher nfkmverify returned error code $CHILD_ERROR"
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_NCIPHER_GETKEYHASH_COMMAND_INVOCATION_ERROR",
	    params  => { 
		CHILD_ERROR => $CHILD_ERROR,
	    },
	    );
    }

    return $keyhash;
}

memoize('__getKeyHash');

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Engine::nCipher

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

=item * SECRET ()

=item * CERT (filename of the certificate)

=item * INTERNAL_CHAIN (filename of the certificate chain)

=item * ENGINE_USAGE (type of the crypto operations where engine should be used)

=item * KEY_STORE (storage type of the token's private key - could be OPENXPKI or ENGINE)

=item * WRAPPER (wrapper for the OpenSSL binary)

=item * ENGINE_SECTION (a part of the OpenSSL configuration file for the engine)

=item * NFAST_HOME (nCipher software home directory, defaults to /opt/nfast)

=item * CHECKCMDTIMEOUT (timeout in secounds for nCipher key check tool commands)

=item * ONLINECHECKGRACEPERIOD ()

=back

=head2 get_engine

returns the used OpenSSL engine or the empty string if no engine
is used.

=head2 get_keyform

returns "e" or "engine" if the key is stored in an OpenSSL engine.

=head2 get_wrapper

returns the wrapper around the OpenSSL binary if such a
wrapper is used (e.g. nCipher's chil engine). Otherwise the empty string
is returned.
