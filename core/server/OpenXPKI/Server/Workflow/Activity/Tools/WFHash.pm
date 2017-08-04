# OpenXPKI::Server::Workflow::Activity::Tools::WFHash
# Written by Scott Hardin for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::WFHash;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Debug;
use OpenXPKI::Server::Workflow::WFObject::WFHash;

#use Data::Dumper;


sub execute {
    my ( $self, $wf ) = @_;

    ##! 1: 'start';

    my $operation = $self->param('function');

    my $hash_name =  $self->param('hash_name');

    my $key =  $self->param('hash_key');
    my $value =  $self->param('hash_value');
    my $target =  $self->param('context_key');

    my $item = { workflow => $wf, context_key => $hash_name };

    ##! 16: 'item ' . Dumper $item;

    my $hash = OpenXPKI::Server::Workflow::WFObject::WFHash->new( $item );

    # auto detect operation
    if (defined $target) {
        $hash->context->param( $target,  $wf->valueForKey($key, $value) );
    } else {
        $hash->setValueForKey($key, $value);
    }

    return 1;
#
#    if ( $function eq 'valueForKey' ) {
#        my $ret = $hash->$function( $context->param( $context_key ) );
#        if ( defined $ret ) {
#            $context->param( $context_key, $ret );
#        } else {
#            $context->param( $context_key, $ret );
#            # for testing, indicate an error
#            if ( defined $context->param( $context_key ) )  {
#                $context->param( $context_key, '<undef>' );
#            }
#        }
#    }
#    # write operations that take a parameter
#    elsif ( $function =~ m/^(push|unshift)$/ ) {
#        $array->$function( $context->param( $context_key ) );
#    }
#    # other operations
#    elsif ( $function eq 'value' ) {
#        my $index_key = $self->index_key;
#        $context->param( $context_key, $array->$function( $context->param( $index_key ) ) );
#    }
#
#    else {
#        OpenXPKI::Exception->throw(
#            message =>
#                'I18N_OPENXPKI_SERVER_WF_ACTIVITY_TOOLS_NSARRAY_MISSING_FUNCTION',
#            params => { name => $function, },
#        );
#    }
#
#    $array = undef;

    return 1;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::WFHash

=head1 Description

Allow array structures to be modelled in the workflow action
definitions using a single implementation class.

=head1 Examples

  <action name="add_cert_to_publish"
    class="OpenXPKI::Server::Workflow::Activity::Tools::WFHash"
    array_name="certs_found"
    function="setValueForKey"
    context_key="_add_cert_key"
    context_val_key="_add_cert_val"
>
  </action>


=head1 Parameters

The following parameters may be set in the definition of the action:

=head2 hash_name

The name of the workflow context parameter containing the hash to be
used

=head2 function

The following functions are supported:

=over 8

=item setValueForKey

Adds the value of the context parameter named in I<context_val_key> to the
the hash in the key name currently in the context parameter named in
I<context_key>.

=back

=head2 context_key

The name of the context parameter that either contains or is the lvalue
for the function.

=head2 context_val_key

When retrieving an element of the array, this specifies the name of the
context parameter that contains the value of the element.

