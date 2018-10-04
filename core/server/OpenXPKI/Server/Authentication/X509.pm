## OpenXPKI::Server::Authentication::X509.pm
##
## Rewritten 2013 by Oliver Welter for the OpenXPKI Project
## (C) Copyright 2013 by The OpenXPKI Project
package OpenXPKI::Server::Authentication::X509;

use strict;
use warnings;
use English;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::X509;
use MIME::Base64;

use Moose;

use Data::Dumper;

has path => (
    is => 'ro',
    isa => 'Str',
);

has trust_certs => (
    is => 'rw',
    isa => 'ArrayRef',
);

has trust_realms => (
    is => 'rw',
    isa => 'ArrayRef',
);

has trust_anchors => (
    is => 'rw',
    isa => 'ArrayRef',
    builder => '_load_anchors',
    lazy => 1
);


## constructor and destructor stuff

around BUILDARGS => sub {

    my $orig = shift;
    my $class = shift;

    my $path = shift;

    return $class->$orig({ path => $path });

};


sub BUILD {

    my $self = shift;

    my $path = $self->path();
    ##! 2: "load name and description for handler"

    my $config = CTX('config');

    my @trust_certs =  $config->get_scalar_as_list("$path.cacert");
    my @trust_realms = $config->get_scalar_as_list("$path.realm");

    ##! 8: 'Config Path: ' . $path
    ##! 8: 'Trusted Certs ' . Dumper @trust_certs
    ##! 8: 'Trusted Realm ' . Dumper @trust_realms

    $self->trust_certs ( \@trust_certs );
    $self->trust_realms ( \@trust_realms );

    $self->{DESC} = $config->get("$path.description");
    $self->{NAME} = $config->get("$path.label");

    $self->{ROLE} = $config->get("$path.role.default");
    $self->{ROLEARG} = $config->get("$path.role.argument");

    if ($config->get("$path.role.handler")) {
        my @path = split /\./, "$path.role.handler";
        $self->{ROLEHANDLER} = \@path;
    }


}

sub _load_anchors {

    my $self = shift;


    return CTX('api')->get_trust_anchors({ PATH => $self->path() });

    my $trusted_realms = $self->trust_realms();
    my $trusted_certs = $self->trust_certs();

    ##! 8: 'Trusted Certs ' . Dumper $trusted_certs
    ##! 8: 'Trusted Realm ' . Dumper $trusted_realms

    my @trust_anchors;

    @trust_anchors = @{$trusted_certs} if ($trusted_certs);

    foreach my $trust_realm (@{$trusted_realms}) {
        # Look up the group name used for the ca certificates in the given realm
        ##! 16: 'Load ca signers from realm ' . $trust_realm
        my $ca_certs = CTX('api')->list_active_aliases({ TYPE => 'certsign', PKI_REALM => $trust_realm });
        ##! 16: 'ca cert in realm ' . Dumper $ca_certs
        if (!$ca_certs) { next; }
        push @trust_anchors, map { $_->{IDENTIFIER} } @{$ca_certs};
    }

    if (! scalar @trust_anchors ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_MISSING_TRUST_ANCHOR_CONFIGURATION',
            params => {
                PKI_REALM => CTX('session')->data->pki_realm
            }
        );
   }

    ##! 16: 'trust_anchors: ' . Dumper \@trust_anchors
    return \@trust_anchors;

}

sub login_step {

    # This is an abstract class - please use the implementations!
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_ABSTRACT_CLASS',
    );

}

sub _validation_result {

    my $self = shift;
    my $validate = shift;

    my $default_token = CTX('api')->get_default_token();

    ##! 32: 'validation result ' . Dumper $validate
    if ($validate->{STATUS}  ne 'TRUSTED') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_SIGNER_CERT_NOT_TRUSTED',
            params  => {
                'STATUS' => $validate->{STATUS}
            },
        );
    }

    my $x509_signer = OpenXPKI::Crypto::X509->new( DATA => $validate->{CHAIN}->[0], TOKEN => $default_token );
    my $signer_subject = $x509_signer->get_parsed('BODY','SUBJECT');

    ##! 16: ' Signer Subject ' . $signer_subject
    my $dn = OpenXPKI::DN->new( $signer_subject );

    ##! 32: 'dn hash ' . Dumper $dn;
    my %dn_hash = $dn->get_hashed_content();
    ##! 16: 'dn hash ' . Dumper %dn_hash;

    # in the unusual case that there is no dn we use the full subject
    my $user = $signer_subject;
    $user = $dn_hash{'CN'}[0] if ($dn_hash{'CN'});

    # Assign default role
    my $role;
    # Ask connector
    ##! 16: 'Rolehandler ' . Dumper $self->{ROLEHANDLER}
    if ($self->{ROLEHANDLER}) {
        my $handler = $self->{ROLEHANDLER}.".";
        if ($self->{ROLEARG} eq "cn" || $self->{ROLEARG} eq "username") {
            $handler .= $user;
        } elsif ($self->{ROLEARG} eq "subject") {
            $handler .= $x509_signer->{PARSED}->{BODY}->{SUBJECT};
        } elsif ($self->{ROLEARG} eq "serial") {
            $handler .= $x509_signer->{PARSED}->{BODY}->{SERIAL};
        } else {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_CERT_UNKNOWN_ROLE_HANDLER_ARGUMENT',
                params  => {
                    'ARGUMENT' => $self->{ROLEARG},
                },
                log => {
                    priortity => 'fatal',
                    facility => 'system',
                }
            );
        }
        $role = CTX('config')->get( $handler );
        ##! 16: 'role: ' . $role
    }

    $role = $self->{ROLE} unless($role);

    ##! 16: 'role: ' . $role
    if (!$role) {
        ##! 16: 'no certificate role found'
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_LOGIN_FAILED",
            params  => {
                USER => $signer_subject,
                REASON => 'no role'
        });
    }

    return ($user, $role, { SERVICE_MSG => 'SERVICE_READY', } );

}

1;
__END__

=head1 Name

OpenXPKI::Server::Authentication::X509 - certificate based authentication.

=head1 Description

Use a certificate chain passed by the authenticator to authenticate the user.
This is an abstract base class, the actual challenge and extractin of the chain is
done in ChallengeX509 and ClientX509 class, the later validation performs several steps:

* look up a suitable root certificate, either in the received chain or in the database.
* do a cryptographic validation on the chain.
* check if any of the certificates (entity, chain or root) is contained in the trust anchor list.

Any failure results in an exception.


=head1 Functions

=head2 _load_anchors

Create a list of trust anchor identifiers from the configuration.

=head2 login_step

returns a pair of (user, role, response_message) for a given login
step. Noop - needs to be implemented by the inherited classes.

=head1 configuration

Signature:
    type: ChallengeX509
    label: Signature
    description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_SIGNATURE
    role:
        handler: @auth.roledb
        argument: dn
        default: ''
    # trust anchors
    realm:
    - my_client_auth_realm
    cacert:
    - cert_identifier of external ca cert

=head2 parameters

=over

=item role.handler

A connector that returns a role for a give user

=item role.argument

Argument to use with hander to query for a role. Supported values are I<cn> (common name), I<subject>, I<serial>

=item role.default

The default role to assign to a user if no result is found using the handler.
If you do not specify a handler but a default role, you get a static role assignment for any matching certificate.

=item cacert

A list of certificate identifiers to be used as trust anchors

=item realm

A list of realm names to be used as trust anchors (this loads all ca certificates from the given realm into the list of trusted ca certs).

=back
