# OpenXPKI::Server::Workflow::Activity::Tools::WFArray
# Written by Scott Hardin for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::WFArray;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Debug;
use OpenXPKI::Server::Workflow::WFObject::WFArray;

#use Data::Dumper;

my @REQ_PROPS = qw( array_name function );
my @OPT_PROPS = qw( context_key index_key index );
__PACKAGE__->mk_accessors( @REQ_PROPS, @OPT_PROPS );

sub new {
    my ( $class, $wf, $params ) = @_;
    my $self = $class->SUPER::new( $wf, $params );

    # set only our extra properties from action class def
    foreach my $prop (@REQ_PROPS) {
        if ( not defined $params->{$prop} ) { # These properties are mandatory
            warn "ERR - MISSING PARAM '$prop'";
            OpenXPKI::Exception->throw(
                message =>
                    'I18N_OPENXPKI_SERVER_WF_ACTIVITY_TOOLS_NSARRAY_MISSING_PARAM',
                params => { name => $prop, },
            );
        }
        $self->$prop( $params->{$prop} );
    }
    foreach my $prop (@OPT_PROPS) {
        if ( defined $params->{$prop} ) {
            $self->$prop( $params->{$prop} );
        }
    }
    return $self;
}

sub execute {
    my ( $self, $wf ) = @_;
    my $function    = lc($self->function());
    my $context     = $wf->context();
    my $context_key = $self->context_key();

    my $array = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
        { workflow => $wf, context_key => $self->array_name } );

    # read operations that do not take a parameter
    if ( $function =~ m/^(pop|shift|count)$/ ) {
        my $ret = $array->$function;
        if ( defined $ret ) {
            $context->param( $context_key, $ret );
        } else {
            $context->param( $context_key, $ret );
            # for testing, indicate an error
            if ( defined $context->param( $context_key ) )  {
#                $context->param( $context_key, '<undef>' );
            }
        }
    }
    # write operations that take a parameter
    elsif ( $function =~ m/^(push|unshift)$/ ) {
        $array->$function( $context->param( $context_key ) );
    }
    # write operations that take a parameter
    elsif ( $function =~ m/^(pusharray|unshiftarray)$/ ) {
	$function =~ s{ array \z }{}xms;

	my $arg = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    { workflow => $wf, context_key => $context_key } );

        $array->$function( @{$arg->value()} );
    }
    # other operations
    elsif ( $function eq 'value' ) {
	my $index = $self->index;

	if (! defined $index) {
	    my $index_key = $self->index_key;
	    $index = $context->param($index_key);
	}

	if (! defined $index) {
	    OpenXPKI::Exception->throw(
		message =>
                'I18N_OPENXPKI_SERVER_WF_ACTIVITY_TOOLS_NSARRAY_MISSING_INDEX',
		params => { name => $function, },
		);
	}

        $context->param( $context_key, $array->$function($index) );
    }

    else {
        OpenXPKI::Exception->throw(
            message =>
                'I18N_OPENXPKI_SERVER_WF_ACTIVITY_TOOLS_NSARRAY_MISSING_FUNCTION',
            params => { name => $function, },
        );
    }

    $array = undef;
    return 1;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::WFArray

=head1 Description

Allow array structures to be modelled in the workflow action
definitions using a single implementation class.

=head1 Examples

  <action name="add_cert_to_publish"
    class="OpenXPKI::Server::Workflow::Activity::Tools::WFArray"
    array_name="cert_publish_queue"
    function="push"
    context_key="next_cert_to_publish">
  </action>


=head1 Parameters

The following parameters may be set in the definition of the action:

=head2 array_name

The name of the workflow context parameter containing the array to be
used

=head2 function

The following functions are supported:

=over 8

=item push

Adds the value of the context parameter named in I<context_key> to the 
end of the array

=item pusharray

Adds the array contents contained in context parameter named in 
I<context_key> to the end of the array.

=item pop

Removes the last value from the end of the array and assigns it to the
context parameter named in I<context_key>.

=item unshift

Adds the value of the context parameter named in I<context_key> to the 
beginning of the array

=item unshiftarray

Adds the array contents contained in context parameter named in 
I<context_key> to the beginning of the array

=item shift

Removes the last value from the beginning of the array and assigns it
to the context parameter named in I<context_key>.

=item value

Returns the value at the position specified in I<array_index> and 
assigns it to the context parameter named in I<context_key>.

If activity configuration explicitly sets I<index> this value is taken,
otherwise the index is taken from the context value contained in I<index_key>.

=item count

Returns the number of items in the array.

=back

=head2 context_key

The name of the context parameter that either contains or is the lvalue
for the function.

=head2 index_key

When retrieving an element of the array, this specifies the name of the
context parameter that contains the index of the element.

