package OpenXPKI::Server::Authentication::X509;

use strict;
use warnings;
use English;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypt::X509;
use MIME::Base64;

use Moose;
use OpenXPKI::Server::Authentication::Handle;

extends 'OpenXPKI::Server::Authentication::Base';

use Data::Dumper;

has path => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub {
        my $self = shift;
        CTX('log')->deprecated()->error('Please use prefix instead of path');
        return $self->prefix();
    }
);

has trust_anchors => (
    is => 'rw',
    isa => 'ArrayRef',
    builder => '_load_anchors',
    lazy => 1
);

has default_role => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        CTX('log')->deprecated()->error('Please use role instead of default_role');
        return $self->role();
    }
);

has user_arg => (
    is => 'rw',
    isa => 'Str',
    default => 'subject'
);

sub BUILD {

    my $self = shift;

    my @prefix = @{$self->prefix()};

    ##! 2: "load name and description for handler"

    my $config = CTX('config');

    OpenXPKI::Exception->throw(
        message => 'x509 authentication requires default role or user handler!',
    ) unless ($self->has_role() || CTX('config')->exists([ @prefix, 'user' ]));

    if (my $arg = $config->get([ @prefix, 'arg' ])) {
        $self->user_arg($arg);
        OpenXPKI::Exception->throw(
            message => 'x509 client authentication: certificate as argument without handler!',
        ) if ($arg eq "certificate" && !CTX('config')->exists([ @prefix, 'user' ]));
    }

}

sub _load_anchors {

    my $self = shift;
    return CTX('api2')->get_trust_anchors( path => [ @{$self->prefix()}, 'trust_anchor' ] );

}

sub _validation_result {

    my $self = shift;
    my $validate = shift;

    ##! 32: 'validation result ' . Dumper $validate

    return OpenXPKI::Server::Authentication::Handle->new(
        error => OpenXPKI::Server::Authentication::Handle::LOGIN_FAILED,
        error_message => 'client certificate validation faild with status ' . $validate->{status},
    ) unless($validate->{status} eq 'TRUSTED');


    my @prefix = @{$self->prefix()};

    my $x509_signer = OpenXPKI::Crypt::X509->new( $validate->{chain}->[0] ) ;
    my $signer_subject = $x509_signer->get_subject();

    ##! 16: ' Signer Subject ' . $signer_subject
    my $dn = OpenXPKI::DN->new( $signer_subject );

    ##! 32: 'dn hash ' . Dumper $dn;
    my %dn_hash = $dn->get_hashed_content();
    ##! 16: 'dn hash ' . Dumper %dn_hash;

    my $has_handler = CTX('config')->exists([ @prefix, 'user' ]);
    # Argument to use as username
    my $arg = $self->user_arg();
    my $username;

    if ($arg eq "subject" || $arg eq "dn") {
        $username = $x509_signer->get_subject();
    } elsif ($arg eq "serial") {
        $username = $x509_signer->get_serial();
    } elsif ($arg eq "cert_identifier") {
        $username = $x509_signer->get_cert_identifier();
    } elsif ($arg eq "certificate") {
        $username = $x509_signer->pem;
    } else {
        $arg = uc($arg);
        return OpenXPKI::Server::Authentication::Handle->new(
            error => OpenXPKI::Server::Authentication::Handle::UNKNOWN_ERROR,
            error_message => 'x509 client authentication requires '.$arg.' but certificate has none!',
        ) unless($dn_hash{$arg} && $dn_hash{$arg}[0]);
        $username = $dn_hash{$arg}[0];
    }

    # fetch userinfo from handler
    my $userinfo;
    my $role = $self->default_role();

    if ($has_handler) {
        $userinfo = $self->get_userinfo($username);

        return OpenXPKI::Server::Authentication::Handle->new(
            username => $username,
            error => OpenXPKI::Server::Authentication::Handle::USER_UNKNOWN,
        ) unless($userinfo && $userinfo->{username});

        # set role if no default role was set
        $role = $userinfo->{role} unless ($role);
        delete $userinfo->{role};
        $username = $userinfo->{username};
        delete $userinfo->{username};

    }

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        error => OpenXPKI::Server::Authentication::Handle::NOT_AUTHORIZED,
    ) unless($role);

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        userid => $username,
        role => $role,
        userinfo => $userinfo,
        authinfo => {
            uid => $username,
            %{$self->authinfo},
        },
    );

}

1;
__END__

=head1 Name

OpenXPKI::Server::Authentication::X509 - certificate based authentication.

=head1 Description

Use a certificate chain passed by the authenticator to authenticate the user.
This is an abstract base class, the actual challenge and extraction of the chain is
done in ChallengeX509 and ClientX509 class, the later validation performs several steps:

* look up a suitable root certificate, either in the received chain or in the database.
* do a cryptographic validation on the chain.
* check if any of the certificates (entity, chain or root) is contained in the trust anchor list.

Any failure results in an exception.

=head1 Functions

=head2 _load_anchors

Create a list of trust anchor identifiers by calling I<get_trust_anchors>
passing the config node I<trust_anchor> as path argument.

=head2 login_step

returns a pair of (user, role, response_message) for a given login
step. Noop - needs to be implemented by the inherited classes.

=head1 configuration

Signature:
    type: ChallengeX509
    label: Signature
    description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_SIGNATURE
    role: User
    user:
        John Doe:
            username: jdoe
            realname: John Doe
    arg: cn
    # trust anchors (see also get_trust_anchors API method)
    trust_anchor:
        realm:
         - my_client_auth_realm
        cacert:
         - cert_identifier of external ca cert
        alias:
         - name of alias groups

=head2 parameters

=over

=item role

The role assigned to the user, if not specified a user section that
returns the role is mandatory!

=item user

Hash holding additional user information, usually implemented as a
connector reference, see below.

=item arg

The certificate property used as username. Supported values are:

=over

=item I<subject> / I<dn>

The full subject/dn as string, this is also the default

=item I<serial>

Serial in integer notation - as string

=item I<certificate>

The PEM encoded certificate

=item I<cert_identifier>

The cert_identifier.

I<Note>: If you use certificates from an external CA you will not be able
to resolve the identifier back to any information unless you import them
into the certificate database!

=item I<*>

Any part that is set in the DN hash, if an attribute is multivalued the
first item is used.

=back

=item trust_anchor

Definition of trust anchors used when validating the certificate, this
node is mandatory and must have at least one keywords supported by the
I<get_trust_anchors> API method.

=back

=head2 Examples

=head3 Static

Allow all certiticates issued from the internal realm I<user-ca> and set
their role to I<User>. Set CN as username (default).

    type: ClientX509
    role: User
    trust_anchor:
        realm: user-ca

=head3 Static role, extended user information from CN

Querys the given connector with the full DN as argument, expects a hash
that contains at least the key I<username>, all other keys are made
available in the C<userinfo> structure (e.g. I<realname> and I<emailaddress>).

    type: ClientX509
    role: User
    user@: connector:my.user.info.source
    arg: subject
    trust_anchor:
        realm: user-ca

=head3 Dynamic role

Similar to above but as I<role> is not set in the config the hash
returned by the connector must also contain I<role>. As I<arg> is also
not set the query parameter given to the connector is only the common name.

    type: ClientX509
    user@: connector:my.user.info.source
    trust_anchor:
        realm: user-ca
