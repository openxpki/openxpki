package OpenXPKI::Server::Workflow::Helpers;
use OpenXPKI;

use Workflow::Exception qw( configuration_error );

use OpenXPKI::Serialization::Simple;

=head2 get_service_config_path

Helper to pull in information from the config layer with fallback to
I<interface>.I<server>.I<default_path>.

The method looks for the parameter I<config_path> first, if this is not
set, it reads I<interface> and I<server> from the context and adds the
value given as parameter to the method as last path component. If you
need to add more than one path element pass as array ref.

The return value is an array ref with the full path that can be given
to the config layer. A configuration_error will occur if the method
is unable to build the path due to missing input data.

=cut

sub get_service_config_path {

    my $workflow_class = shift;
    my $default_path = shift || '';

    my @prefix;

    if (my $config_path = $workflow_class->param('config_path')) {
        ##! 32: 'Explicit config path is set ' . $config_path
        @prefix = split /\./, $config_path;
    # auto create from interface and server in context if not set
    } elsif ($default_path) {
        my $context = $workflow_class->workflow()->context();
        my $interface = $context->param('interface');
        my $server = $context->param('server');

        if (!$server || !$interface) {
            configuration_error('Neither config_path nor interface/server is set!');
        }

        @prefix = ( $interface, $server );
        if (ref $default_path) {
            push @prefix, @{$default_path};
        } else {
            push @prefix, $default_path;
        }
        ##! 32: 'Autobuild config_path from interface ' . join ".", @prefix
    } else {
        configuration_error('Neither config_path nor ruleset_path is set!');
    }

    return \@prefix;

}

=head2 get_value_from_context

Helper to fetch a value from the context.

Deserialised the value in case it is an object.

=cut

sub get_value_from_context {

    my $workflow_class = shift;
    my $ctxkey = shift;

    my $ctx = $workflow_class->workflow()->context()->param( $ctxkey );
    if (!defined $ctx || $ctx eq '') {
        return $ctx;
    }
    if (OpenXPKI::Serialization::Simple::is_serialized($ctx)) {
        ##! 32: ' needs deserialize '
        my $ser  = OpenXPKI::Serialization::Simple->new();
        $ctx = $ser->deserialize( $ctx );
    }
    return $ctx;

}

1;

__END__;