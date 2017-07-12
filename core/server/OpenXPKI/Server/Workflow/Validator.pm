
package OpenXPKI::Server::Workflow::Validator;

use strict;

use Moose;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use Data::Dumper;

extends 'Workflow::Validator';

has 'params' => (
    is => 'rw',
    isa => 'HashRef',
);

has '_map' => (
    is => 'rw',
    isa => 'HashRef',
);

has 'workflow' => (
    is => 'rw',
    isa => 'Object',
);


sub _init {
    my ( $self, $params ) = @_;

    # copy the source params
    my $params_merged = { % { $params }};

    # init the _map parameters
    my $_map = {};

    foreach my $key (keys %{$params}) {
        if ($key !~ /^_map_(.*)/) { next; }

        # Remove map key from the hash
        delete $params_merged->{$key};

        my $name = $1;
        my $val = $params->{$key};
        $_map->{$name} = $params->{$key};
        ##! 8: 'Found param ' . $name . ' - value : ' . $params->{$key}

    }

    $self->params( $params_merged );
    $self->_map( $_map );

    ##! 32: 'merged params ' . Dumper  $params_merged
    ##! 32: 'map ' . Dumper  $_map

    ##! 1: 'end'
    return 1;
}

sub param {

    my ( $self, $name ) = @_;

    unless ( defined $name ) {
        my $result = { %{ $self->params() } };

        # add mapped params
        my $map = $self->_map();
        foreach my $key (keys %{ $map }) {
            $result->{$key} = $self->param( $key );
        }
        return $result;
    }

    if ( exists $self->params()->{$name} ) {
        return $self->params()->{$name};
    } else {
        my $map = $self->_map();
        return undef unless ($map->{$name});
        ##! 16: 'query for mapped key ' . $name

        my $template = $map->{$name};
        # shortcut for single context value
        if ($template =~ /^\$(\S+)/) {
            my $ctxkey = $1;
            ##! 16: 'load from context ' . $ctxkey
            my $ctx = $self->workflow()->context()->param( $ctxkey );
            if (OpenXPKI::Serialization::Simple::is_serialized($ctx)) {
                ##! 32: ' needs deserialize '
                my $ser  = OpenXPKI::Serialization::Simple->new();
                return $ser->deserialize( $ctx );
            } else {
                return $ctx;
            }
        } else {

            ##! 16: 'parse using tt ' . $template
            my $oxtt = OpenXPKI::Template->new();
            my $out = $oxtt->render( $template, {  context => $self->workflow()->context()->param() } );

            ##! 32: 'tt result ' . $out
            return $out;
        }
    }
    return undef;
}

sub validate {

    ##! 1: 'start'

    my $self = shift;
    my $workflow = shift;
    my @args = @_;

    $self->workflow( $workflow );

    my @args_parsed = ();

    # evaluate the arguments, $context escaping is already done by the
    # workflow factory, now we look for TT strings and parse them.
    # Note that the string must start with the TT marker to be recognized

    my $oxtt = OpenXPKI::Template->new();

    if (scalar @args) {
        ##! 32: 'validator args are ' . Dumper \@args
        foreach my $arg (@args) {
            if (!defined $arg) {
                $arg = '';
            } elsif (ref $arg eq '' && $arg =~ m{ \A \s* \[%.+%\] }xsm) {
                ##! 16: 'Found template ' . $arg
                $arg = $oxtt->render( $arg, {  context => $workflow->context()->param() } );
                ##! 16: 'render result ' . $arg
            }
            push @args_parsed, $arg;
        }
    } else {
        ##! 8: 'Use preset'
        my $preset = $self->_preset_args();
        foreach my $arg (@{$preset}) {
            my $value = $workflow->context()->param( $arg );
            ##! 16: 'Push preset ' . $arg . ' : ' . (defined $value ? $value : 'undef')
            push @args_parsed, $value;
        }
    }

    ##! 32: 'Validator argument values: ' . Dumper \@args_parsed

    unshift @args_parsed, $workflow;

    $self->_validate( @args_parsed );

    return 1;

}

# Implement this (with the underscore) in your subclass
sub _validate {

    my $self = shift;
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_VALIDATOR_SUB_NOT_IMPLEMENTED',
        params => {
            'CLASS' => ref $self,
        }
    );

}

sub _preset_args {
    my $self = shift;
    return undef;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Validator

=head1 SYNOPSIS

  my_validator
    class: OpenXPKI::Server::Workflow::Validator::MyValidatorClass
    param:
      _map_path: [% context.key_in_context %]
    arg:
      - $cert_profile
      - $cert_subject_style
      - "[% context.other_key_in_context %]"

=head1 Description

A base clase for Validators, providing some magic for handling parameters
and arguments.

=head2 Parameter Mapping

All parameters (instance configuration), can use the I<_map> syntax to
resolve values from the context. @see OpenXPKI::Server::Workflow::Activity.
B<Note>: Validators are created ONCE per workflow instance and the
parameters are read and evaluated when the validator is created first.


=head2 Argument Parsing

The Workflow base class already replaces arguments starting with a dollar
sign by the approprate context values. In addition, argument values
starting with a template toolkit sequence I<[%...> are parsed using
OpenXPKI::Template with the full workflow context as parameters and the
given argument as template.

=head1 Sub-Classing

=head2 validation

To implement your own validator you need use Moose and inherit from this
class. Please implement your code in a method called I<_validate>, starting
with and underscore! If you dont need the features from this class, you
can also subclass directly from Workflow::Validator.

Validation errors MUST be thrown using the I<validation_error> method. The
first argument MUST be a verbose description starting with I<I18N_OPENXPKI_UI_>,
you SHOULD pass a list of the fields that caused the error as second argument:

   validation_error ('I18N_OPENXPKI_UI_VALIDATOR_FIELD_HAS_ERRORS',
       { invalid_fields => \@fields_with_error } );

Where each item in the list is a hash with the key I<name> and, optional,
additional infos on the error. (this is not fully specified and also not
evaluated on the UI)

=head2 preset

The validator pattern is usually not bound to the context sensitive and
expects the values to be validated as arguments. As OpenXPKI widely uses
normalized context key names, you can define a preset list to be used
instead of arguments set in the config. Define the sub I<_preset_args>:

  sub _preset_args {
    return [ qw(cert_profile cert_subject_style) ];
  }

If no arguments are set in the validator definition, the constructor reads
the context values at the given keys and injects them as arguments to the
_validate method. The given preset example will set the first two arguments
in the same way as the initial example code with the third parameter
remaining undefined. B<Note>: The preset arguments are not expanded! You
need to pass the context keys as string without leading "$" and can not use
templates or static values.

=head2 Logging

Log event for validation process must use facility application and
should use priorities error and debug. Configuration errors should
trigger OpenXPKI::Exception and log to workflow/error.


