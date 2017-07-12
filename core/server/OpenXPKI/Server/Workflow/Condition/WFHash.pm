# OpenXPKI::Server::Workflow::Condition::WFHash
# Written by Oliver Welter for the OpenXPKI project 2012
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Condition::WFHash;

use strict;
use warnings;
use base qw( Workflow::Condition );
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Workflow::WFObject::WFHash;
use OpenXPKI::Debug;
use Data::Dumper;
use English;

my @parameters = qw(
    hash_name
    condition
    ds_key
);

__PACKAGE__->mk_accessors(@parameters);

sub _init {
    my ( $self, $params ) = @_;

    # propagate workflow condition parametrisation to our object
    foreach my $arg (@parameters) {
        if ( defined $params->{$arg} ) {
            $self->$arg( $params->{$arg} );
        }
    }

    foreach my $arg (qw(hash_name condition ds_key)) {
        if ( !( defined $self->$arg() ) ) {
        configuration_error
            "Missing parameter '.$arg.' in " .
            "declaration of condition " . $self->name();
        }
    }
}


sub evaluate {
    my ( $self, $wf ) = @_;
    my $context = $wf->context();


    my $hash = OpenXPKI::Server::Workflow::WFObject::WFHash->new(
    {
        workflow => $wf,
        context_key => $self->hash_name(),
    } );

    my $key = $self->ds_key();

    if ($key =~ m{ \A \$ (.*) }xms) {
        $key = $context->param($1);
    }

   my $val = $hash->valueForKey($key);

   ##! 16: ' Key: ' . $key . ' - Value ' . Dumper ( $val )

   CTX('log')->application()->debug("Testing if WFHash ". $self->hash_name() ." key $key is " . $self->condition());


    if ($self->condition() eq 'key_defined') {
       if (defined $val) {
           ##! 16: ' Entry is defined '
           return 1;
       }
       ##! 16: ' Entry not defined '
       condition_error
        'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_WFHASH_KEY_NOT_DEFINED';
    } elsif ($self->condition() eq 'key_nonempty') {
       if (defined $val && $val) {
           ##! 16: ' Entry not empty '
           return 1;
       }
       ##! 16: ' Entry is empty '
       condition_error
        'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_WFHASH_KEY_IS_EMPTY';
    } else {
        configuration_error
            "Invalid condition " . $self->condition() . " in " .
            "declaration of condition " . $self->name();
    }
}

1;
__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::WFHash

=head1 SYNOPSIS

  <condition
     name="cert_exists"
     class="OpenXPKI::Server::Workflow::Condition::WFHash">
    <param name="hash_name" value="cert_map"/>
    <param name="condition" value="key_defined"/>
    <param name="ds_key" value="key_to_check"/>
  </condition>

=head1 DESCRIPTION

Allows for checks on a hash stored as a workflow context parameter.

=head1 PARAMETERS

=head2 hash_name

The name of the workflow context parameter containing the hash to be used

=head2 condition

The following conditions are supported:

=over 8

=item key_defined

Condition is true if the key has a value.
The key must be given with the "key" param.

=item key_nonempty

Condition is true if the key has a non-empty value
The key must be given with the "key" param.

=back

=head2 ds_key

If key starts with $, the key value is taken from the context parameter.
