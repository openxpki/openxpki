package OpenXPKI::Server::Workflow::Validator::CertIdentifierExists;

use strict;
use warnings;
use Moose;
use Workflow::Exception qw( validation_error );
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Server::Context qw( CTX );

extends 'OpenXPKI::Server::Workflow::Validator';


sub _preset_args {
    return [ qw(cert_identifier) ];
}

sub _validate {
    my ( $self, $wf, $cert_identifier ) = @_;

    ##! 1: 'start'
    ##! 16: 'check identifier' . $cert_identifier
    my $cert = CTX('dbi')->select_one(
        from => 'certificate',
        columns => [ 'pki_realm', 'req_key' ],
        where => { identifier => $cert_identifier },
    );

    if (!$cert) {
        ##! 16: 'unknown identifier ' . $cert_identifier
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_CERT_IDENTIFIER_EXISTS_NO_SUCH_ID");
    }

    my $pki_realm = $self->param('pki_realm') || CTX('session')->data->pki_realm;

    if ($self->param('entity_only') && !$cert->{req_key}) {
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_CERT_IDENTIFIER_EXISTS_NOT_AN_ENTITY");
    }

    my $group = $self->param('in_alias_group');
    if ($self->param('is_token')) {
        $group = CTX('config')->get(['crypto','type', $self->param('is_token')]);
    }

    if ($group) {
        my $alias = CTX('dbi')->select_one(
            from => 'aliases',
            columns => [ 'alias' ],
            where => {
                identifier => $cert_identifier,
                group_id => $group,
                pki_realm => CTX('session')->data->pki_realm,
            },
        );
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_CERT_IDENTIFIER_IS_NOT_IN_GROUP") unless($alias);
        CTX('log')->application()->trace("Found alias " . $alias->{alias} );

    } elsif (($cert->{pki_realm} ne $pki_realm) && ($pki_realm ne '_any')) {
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_CERT_IDENTIFIER_EXISTS_NOT_IN_REALM");
    }


    CTX('log')->application()->trace("Found certificate, hash is " . Dumper $cert);

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::CertIdentifierExists

=head1 SYNOPSIS

    class: OpenXPKI::Server::Workflow::Validator::CertIdentifierExists
    param:
        entity_only: 1
        pki_realm: _any
    arg:
      - $cert_identifier

=head1 DESCRIPTION

This validator checks whether a given certificate identifier exists. Based
on the parameters it can check weather the certificate is in a given realm
and if it is an entity certificate. Both parameters are optional. Note that
there is no check on the validity of the certificate.

To check if the certificate identifier is an register alias, you can set
I<is_token> or I<in_alias_group>. This requires that an entry in the alias
table exists with the given properties. Note that those flags expect the
alias to be registered in the current session realm and do not check the
realm of the certificate itself, any value given to I<pki_realm> is ignored.

=head2 Argument

=over

=item $cert_identifier

The certificate identifier

=back

=head2 Parameter

=over

=item pki_realm

Can be the name of a realm or the special word I<_any>. If not given, default
ist to check in the session realm only!

=item entity_only

If set, the certificate must be an entity certificate.

=item is_token

Expects the name of a token type as defined in crypto.type and checks if
the certificate has an registered alias matching this token type in the
current realm.

=item in_alias_group

Expects the name of an alias group and checks if the certificate has an
registered alias in this group.

=back
