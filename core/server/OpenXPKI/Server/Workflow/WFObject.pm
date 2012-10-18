# OpenXPKI::Server::Workflow::WFObject
# Written by Scott Hardin for the OpenXPKI Project 2010
# Copyright (c) 2010 by the OpenXPKI Project

package OpenXPKI::Server::Workflow::WFObject;
use Class::Std;
{
    use strict;

    #use base qw( Class::Std );
    use Carp qw( confess );
    use OpenXPKI::Debug;
    use Data::Dumper;
    use English;

    # Storage for object attributes
    my %workflow_of : ATTR( name => 'workflow' );
    my %context_key_of : ATTR( name => 'context_key' );
    my %need_update : ATTR;
    my %serializer : ATTR;
    my %data_ref : ATTR;

    # IMPORTANT: usually, new() is not overridden when using Class::Std. We
    # hack this here, however, to be able to "do the right thing" and return
    # the correct type (e.g.: WFArray) if the parameter already exists.
    #    sub new2 {
    #        my $self = shift;
    #        warn "WFObject: in new2 self='$self'";
    #        return $self;
    #    }

    # Handle initialization of objects of this class
    sub BUILD {
        my ( $self, $id, $args ) = @_;

    #    # sanity checks
    #    if ( not defined $workflow{ $id } ) {
    #        confess "Required attribute 'workflow' not set";
    #    } elsif ( ref( $workflow{ $id } ) ne 'HASH' ) {
    #        confess "Required attribute 'workflow' must be a hash reference";
    #    } elsif ( not exists $workflow{ $id }->{context} ) {
    #        confess "Required attribute 'workflow' must have context key";
    #    }

        # TODO: Add sanity checks for context key!!

        # SHORTCIRCUIT INIT CODE HERE!!!!

        #    warn "ARGS=", join(', ', %{ $args });
        #    warn "XXX context_key=", $context_key_of{ $id };
        #    return;
        #    my $context = $workflow_of{ ident $self }->{context};
        #    $self->set_serializer( OpenXPKI::Serialization::Simple->new() );

        my $ser = $serializer{$id} = OpenXPKI::Serialization::Simple->new();

        my $context_key = $args->{context_key};
        my $raw_data;

        my $context
            = defined $args->{context}
            ? $args->{context}
            : $args->{workflow}->{context};

        if ($context) {
            $raw_data = $context->param($context_key);
        }
        elsif ( exists $args->{workflow}->{CONTEXT} ) {
            $context = $args->{workflow}->{CONTEXT};
            $raw_data = $context->{$context_key};
        }
        else {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_WFOBJECT_DESERIALIZE_ERR',
                params  => {
                    'ERROR' => 'WFObject created without workflow context'
                }
            );
            return;
        }


        if ( defined $raw_data ) {
            my $data;

            # put this in eval to prevent complete blow-up
            eval { $data = $ser->deserialize($raw_data); };
            if ( my $exc = OpenXPKI::Exception->caught() ) {

                # append some details and re-throw exception

                my $params = $exc->params();
                $params->{MORE_INFO}
                    = "WFObject had problem deserializing context parameter '"
                    . $context_key . "'";
                $exc->params($params);
                $exc->rethrow();

            }
            if ($EVAL_ERROR) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_WFOBJECT_DESERIALIZE_ERR',
                    params  => { 'ERROR' => $EVAL_ERROR }
                );
            }
            $data_ref{ ident $self } = $data;
        }
    }

    sub write {
        my ($self)  = @_;
        my $id      = ident $self;
        my $context = $workflow_of{$id}->{context};

        #        if ( $need_update{ $id } ) {
        my $raw = $serializer{$id}->serialize( $data_ref{$id} );
        $context->param( $context_key_of{$id}, $raw );

        #        }

    }

    # Handle cleanup
    sub DEMOLISH {
        my ( $self, $id ) = @_;
        my $context = $workflow_of{$id}->{context};

        if ( $need_update{$id} ) {
            my $raw = $serializer{$id}->serialize( $data_ref{$id} );
            $context->param( $context_key_of{$id}, $raw );
        }
    }

    sub _get_data_ref : RESTRICTED {
        my ($self) = @_;
        return $data_ref{ ident $self };
    }

    sub _set_data_ref : RESTRICTED {
        my ( $self, $ref ) = @_;
        return $data_ref{ ident $self } = $ref;
    }

    sub _will_need_update : RESTRICTED {
        my ( $self, $ref ) = @_;
        $need_update{ ident $self }++;
    }
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::WFObject

=head1 DESCRIPTION

sub _get_data_ref : RESTRICTED {
    my ($self) = @_;
    return $data_ref{ ident $self };
}

sub _will_need_update : RESTRICTED {
    $need_update{ ident $self }++;
}
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::WFObject

=head1 DESCRIPTION

WFObject is the root class for the data objects like WFArray and WFHash. 
It is used to manage the basic attributes and serialization needed
by the inheriting classes. It inherits from Class::Std.

=head1 SYNOPSIS

  my $queue = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
    { workflow => $workflow,
    context_key => 'my_queue' } );

  print "my queue contains ", $queue->count, " element(s).\n";

=head1 DEFAULT ACCESSORS

Default accessor methods are available for the supported properties,
depending on how they are declared. 

=over 8

=item new

When creating a new instance, the named-parameter list with the keys
"workflow" and "context_key" is passed. When creating a new parameter,
use the corresponding data type (e.g.: WFArray). If the parameter 
already exists, WFObject will try to determine the current contents
and return the correct object type.

=item get

The read accessor is available as the name of the property prepended
with 'get_'. The current value of the property is returned.

=item set

The write accessor is available as the name of the property prepended
with 'set_'. The new value is passed as a parameter.

=back

=head1 PROPERTIES

=head2 workflow

A reference to the current workflow instance. 

=head2 context_key

The name of the workflow context parameter where the data structure is
(to be) stored.

=head1 INTERNAL SUBROUTINES

The following subroutines are only available to the class itself.

=head2 _read

Reads and deserializes the contents of the workflow context parameter.

