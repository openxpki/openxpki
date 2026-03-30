package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::GetNamespaceEntries;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw(configuration_error workflow_error);


sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $params = {
        namespace => $self->param('namespace'),
        values    => 1,
        deserialize => 1,
    };

    if (!$params->{namespace}) {
        configuration_error('Datapool::GetNamespaceEntries requires the namespace parameter');
    }

    if (my $key = $self->param('key')) {
        $params->{key_name} = $key;
    }

    for my $opt (qw( limit reverse )) {
        my $val = $self->param($opt);
        $params->{$opt} = $val if defined $val;
    }

    if (my $order = $self->param('order')) {
        $params->{order} = [ split /\s*,\s*/, $order ];
    }

    if ($self->param('pki_realm')) {
        if ($self->param('pki_realm') eq '_global') {
            $params->{pki_realm} = '_global';
        } elsif ($self->param('pki_realm') ne CTX('session')->data->pki_realm) {
            workflow_error( 'Access to foreign realm is not allowed' );
        }
    }

    my $target_key = $self->param('target_key') || '_tmp';

    ##! 16: ' Fetch namespace from datapool ' . Dumper $params
    my $entries = CTX('api2')->list_data_pool_entries(%$params);
    ##! 32: ' Result from datapool ' . Dumper $entries

    my @values = map { $_->{value} } @$entries;

    $context->param({ $target_key => \@values });

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Datapool::GetNamespaceEntries

=head1 Description

Retrieve all entries from a Datapool namespace and write their values to
a workflow context parameter as a list.

=head1 Configuration

=head2 Parameters

In the activity definition, the following parameters must be set.

=over 8

=item namespace

The namespace to query. Required.

=item target_key

The context key to write the list of values to. Defaults to I<_tmp>.

=item key

Optional search pattern for datapool keys. Supports C<*> as wildcard.

=item limit

Optional maximum number of entries to return.

=item order

Optional comma-separated list of column names to sort by.
Defaults to C<datapool_key, namespace>.

=item reverse

Optional boolean. If set, reverses the sort order.

=item pki_realm

The realm of the datapool items to load, default is the current realm.
Use I<_global> to access the global realm.

=back
