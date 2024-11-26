# OpenXPKI::Server::Workflow::Condition
package OpenXPKI::Server::Workflow::Condition;
use OpenXPKI;

use base qw( Workflow::Condition );

use OpenXPKI::Server::Context qw( CTX );

__PACKAGE__->mk_accessors( qw( workflow params _map ) );

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


sub evaluate {

    ##! 1: 'start'
    my ( $self, $workflow ) = @_;

    $self->workflow( $workflow );

    $self->_evaluate( $workflow );

    return 1;

}

# Implement this (with the underscore) in your subclass
sub _evaluate {

    my $self = shift;
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_CONDITION_EVAL_SUB_NOT_IMPLEMENTED',
        params => {
            'CLASS' => ref $self,
        }
    );

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
        return unless ($map->{$name});
        ##! 16: 'query for mapped key ' . $name

        my $template = $map->{$name};
        # shortcut for single context value
        if ($template =~ m{\A\$(\S+?)(\.(\S+))?\z}) {
            my $ctxkey = $1;
            my $subkey = $3 || '';
            ##! 16: 'load from context ' . $ctxkey . ' subkey: ' .$subkey
            my $ctx = $self->workflow()->context()->param( $ctxkey );
            if (!defined $ctx || $ctx eq '') {
                return $ctx;
            }
            if (OpenXPKI::Serialization::Simple::is_serialized($ctx)) {
                ##! 32: ' needs deserialize '
                my $ser  = OpenXPKI::Serialization::Simple->new();
                $ctx = $ser->deserialize( $ctx );
            }
            if ($subkey) {
                if (ref $ctx eq 'HASH') {
                    return $ctx->{$subkey};
                } elsif (ref $ctx eq 'ARRAY' && $subkey =~ /\A\d+\z/) {
                    return $ctx->[$subkey];
                } else {
                    configuration_error("Subkey requested from _map but value is of wrong data type");
                }
            } else {
                return $ctx;
            }
        } else {

            ##! 16: 'parse using tt ' . $template
            my $oxtt = OpenXPKI::Template->new();
            my $out = $oxtt->render( $template, {
                context => $self->workflow()->context()->param(),
                workflow => {
                    id => $self->workflow()->{id}
                },
                session => {
                    user => CTX('session')->data->user,
                    role => CTX('session')->data->role,
                    userinfo => CTX('session')->data->userinfo,
                    pki_realm => CTX('session')->data->pki_realm
                }
            });

            ##! 32: 'tt result ' . $out
            return $out;
        }
    }
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Condition

=head1 Description

Base class for OpenXPKI Conditions that implements parameter magic. Note that
you need to name your evaluation method I<_evaluate>, with a dash as prefix!
Otherwise the necessary initialisation for the parameter magic will not work.

It is NOT mandatory to use this class, subclassing Workflow::Condition is also
fine if you do not need the extra features.

=head1 Parameter mapping

Parameters in the configuration block that start with I<_map_>
are parsed using template toolkit and imported into the namespace of the
class.

The prefix is stripped and the param is set to the result of the evaluation,
the value is interpreted as template and filled with the context:

  my_condition:
    param:
      _map_my_tt_param: my_prefix_[% context.my_context_key %]

If you just need a single context value, the dollar sign is a shortcut:

  my_condition:
    param:
      _map_my_simple_param: $my_context_key

The values are accessible thru the $self->param call using the basename.

=head2 Configuration example

If C<my_context_key> has a value of foo in the context, this configuration:

  my_condition:
    param:
     _map_my_simple_param: $my_context_key
     _map_my_tt_param: my_prefix_[% context.my_context_key %]


Is the same as:

  my_condition:
    param:
      my_simple_param: foo
      my_tt_param: my_prefix_foo

