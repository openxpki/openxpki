## OpenXPKI::Crypto::Secret.pm 
##
## Written 2006 by Martin Bartosch for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

package OpenXPKI::Crypto::Secret;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

# use Data::Dumper;

use OpenXPKI::Debug;
use OpenXPKI::Exception;

{
    my %impl : ATTR;

    sub START {
	my ($self, $ident, $arg_ref) = @_;

	# only in Command.pm base class: get implementation
	if (ref $self eq 'OpenXPKI::Crypto::Secret') {
	    $self->attach_impl($arg_ref);
	}
    }

    sub attach_impl : PRIVATE {
	my $self = shift;
	my $ident = ident $self;
	my $arg_ref = shift;

	my $type = 'Plain';
	if (defined $arg_ref 
	    && defined $arg_ref->{TYPE} 
	    && (ref $arg_ref->{TYPE} eq '')) {
	    $type = $arg_ref->{TYPE};
	}

	my $base = 'OpenXPKI::Crypto::Secret';
	my $class = $base . '::' . $type;

	##! 8: "try to load class $class"
	eval "use $class;";
	if ($EVAL_ERROR) {
	    OpenXPKI::Exception->throw(
		message => "I18N_OPENXPKI_CRYPTO_SECRET_IMPLEMENTATION_UNAVAILABLE",
		params  => 
		{
		    EVAL_ERROR => $EVAL_ERROR,
		    MODULE     => $class,
		});
	}

	$impl{$ident} = eval "$class->new(\$arg_ref)";

	if (! defined $impl{$ident}) {
	    OpenXPKI::Exception->throw(
		message => "I18N_OPENXPKI_CRYPTO_SECRET_INSTANTIATION_FAILED",
		params  => 
		{
		    EVAL_ERROR => $EVAL_ERROR,
		    MODULE     => $class,
		});
	}

	return 1;
    }

    # dispatch client call to secret class implementation
    sub AUTOMETHOD {
	my ($self, $ident, @other_args) = @_;
	
	##! 1: "AUTOMETHOD($_)"

	my $method = $_;
	return sub {
	    return $impl{$ident}->$method(@other_args);
	}
    }

}

1;

=head1 Name

OpenXPKI::Crypto::Secret - Base class for secrets (e. g. PINs).

=head1 Description

Base class for secret storage.

Subclasses must implement the methods set_secret(), get_secret() and
is_complete(). 

If the secret is fully known, the subclass must return a true value
whenever is_complete() is called.

Once the secret is known the subclass must return the secret whenever
get_secret() is called, otherwise an undefined value should be returned.

See OpenXPKI::Crypto::Secret::Plain for a usage example.

=head2 Methods

=head3 new

Constructor. Select 'Secret' implementation by specifying the named parameter
'TYPE' accordingly. TYPE defaults to 'Plain'.
See OpenXPKI::Crypto::Secret::Plain.

=head3 is_complete

Returns true once the secret is known.
Must be implemented by subclasses.

=head3 get_secret

Returns the resulting secret or undef if not yet available.
Must be implemented by subclasses.

=head3 set_secret

Sets (part of) the secret. 
Must be implemented by subclasses.

