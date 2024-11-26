
package OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicyKeyDuplicate;
use OpenXPKI;

use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DN;
use OpenXPKI::DateTime;
use OpenXPKI::Serialization::Simple;

sub execute
{
    ##! 1: 'Start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $pkcs10 = $self->param('pkcs10');
    $pkcs10 = $context->param('pkcs10') unless ($pkcs10);

    return unless ($pkcs10);

    my $key_identifier = CTX('api2')->get_key_identifier_from_data( data => $pkcs10, format => 'PKCS10' );

    if (!$key_identifier) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_UI_UNABLE_TO_PARSE_PKCS10_REQUEST_DATA');
    }

    ##! 16: 'subject_key_identifier: ' . $key_identifier
    my $query = {
        entity_only => 1,
        subject_key_identifier => $key_identifier,
        return_columns => 'identifier',
        tenant => '',
    };

    if ($self->param('any_realm')) {
        ##! 32: 'Any realm requested'
        $query->{pki_realm} = '_any';
    }

    ##! 32: 'Search duplicate key with query ' . Dumper $query

    my $result = CTX('api2')->search_cert(%$query);

    my $target_key = $self->param('target_key') || 'check_policy_key_duplicate';


    my $ignore = $self->param('cert_identifier_ignore') || '';
    ##! 16: 'Search returned ' . Dumper $result
    my @identifier = map {  ($_->{identifier} eq $ignore) ? () : $_->{identifier} } @{$result};

    if (@identifier) {

        my $ser = OpenXPKI::Serialization::Simple->new();
        $context->param( $target_key , $ser->serialize(\@identifier) );

        CTX('log')->application()->info("Policy key duplicate check failed, found certs " . join(", ", @identifier));


    } else {

        $context->param( { $target_key => undef } );

    }

    return 1;
}

1;

__END__;

=head1 NAME

OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicyKeyDuplicate

=head1 DESCRIPTION

Check if another certificate with the same public key already exists. The
default is to check against entity certificates in the same realm, result
is written as array of identifiers to context at check_policy_key_duplicate
or the given target key.

See the parameters section for other search options.

=head2 Activity parameters

=over

=item pkcs10

PEM encoded PKCS10 data to extract the key from, default uses data found
at context key I<pkcs10>.

=item target_key

Context key to write the result to, default is check_policy_key_duplicate

=item any_realm

Boolean, search certificates globally, optional.

=item cert_identifier_ignore

Pass a single certificate identifier that is removed from the list in case
it was found. This is useful to allow a key reuse on renewal.

=back
