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

use Data::Dumper;


has label => (
    is => 'rw',
    isa => 'Str',
);

has description => (
    is => 'rw',
    isa => 'Str',
);

has path => (
    is => 'ro',
    isa => 'ArrayRef',
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
    default => ''
);

has user_arg => (
    is => 'rw',
    isa => 'Str',
    default => 'subject'
);

## constructor and destructor stuff

around BUILDARGS => sub {

    my $orig = shift;
    my $class = shift;

    my @path = split /\./, shift;

    return $class->$orig({ path => \@path });

};


sub BUILD {

    my $self = shift;

    my @path = @{$self->path()};

    ##! 2: "load name and description for handler"

    my $config = CTX('config');

    ##! 8: 'Config Path: ' . Dumper \@path

    $self->description( $config->get( [ @path, 'description'] ) );
    $self->label( $config->get( [ @path, 'label'] ) );

    if (my $role = $config->get([ @path, 'role' ])) {
        $self->default_role( $role );
    } elsif (!CTX('config')->exists([ @path, 'user' ])) {
        OpenXPKI::Exception->throw(
            message => 'x509 authentication requires default role or user handler!',
        );
    }

    if (my $arg = $config->get([ @path, 'arg' ])) {
        $self->user_arg($arg);
    }

}

sub _load_anchors {

    my $self = shift;
    return CTX('api2')->get_trust_anchors( path => [ @{$self->path()}, 'trust_anchor' ] );

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

    ##! 32: 'validation result ' . Dumper $validate
    if ($validate->{status} ne 'TRUSTED') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_SIGNER_CERT_NOT_TRUSTED',
            params  => {
                'STATUS' => $validate->{status}
            },
        );
    }

    my @path = @{$self->path()};

    my $x509_signer = OpenXPKI::Crypt::X509->new( $validate->{chain}->[0] ) ;
    my $signer_subject = $x509_signer->get_subject();

    ##! 16: ' Signer Subject ' . $signer_subject
    my $dn = OpenXPKI::DN->new( $signer_subject );

    ##! 32: 'dn hash ' . Dumper $dn;
    my %dn_hash = $dn->get_hashed_content();
    ##! 16: 'dn hash ' . Dumper %dn_hash;

    my $has_handler = CTX('config')->exists([ @path, 'user' ]);
    # Argument to use as username
    my $arg = $self->user_arg();
    my $username;

    if ($arg eq "subject" || $arg eq "dn") {
        $username = $x509_signer->get_subject();
    } elsif ($arg eq "serial") {
        $username = $x509_signer->get_serial();
    } elsif ($arg eq "certificate") {
        OpenXPKI::Exception->throw(
            message => 'x509 client authentication: certificate as argument without handler!',
            log => { priortity => 'fatal', facility => 'system' }
        ) if (!$has_handler);
        $username = $x509_signer->pem;
    } else {
        $arg = uc($arg);
        OpenXPKI::Exception->throw(
            message => 'x509 client authentication requires '.$arg.' but certificate has none!',
            log => { priortity => 'fatal', facility => 'system' }
        ) if (!$dn_hash{$arg} || !$dn_hash{$arg}[0]);
        $username = $dn_hash{$arg}[0];
    }

    OpenXPKI::Exception->throw(
        message => 'x509 client unable to set username!',
        log => { priortity => 'fatal', facility => 'system' }
    ) if (!$username);


    # fetch userinfo from handler
    my $userinfo;
    my $role = $self->default_role();

    if ($has_handler) {
        $userinfo = CTX('config')->get_hash( [ @path,  'user', $username ] );

        OpenXPKI::Exception->throw(
            message => 'x509 client authentication did not find user!',
            params => { 'argument' => $arg, username => $username },
            log => { priortity => 'fatal', facility => 'system' }
        ) if (!$userinfo || !$userinfo->{username});

        # set role if no default role was set
        $role = $userinfo->{role} unless ($role);
        delete $userinfo->{role};
        $username = $userinfo->{username};
        delete $userinfo->{username};

    }

    ##! 16: 'role: ' . $role
    if (!$role) {
        ##! 16: 'no certificate role found'
        OpenXPKI::Exception->throw (
            message => 'x509 client authentication did not find role!',
            params  => { username => $username }
        );
    }

    return ($username, $role, { SERVICE_MSG => 'SERVICE_READY', }, $userinfo );

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
    label: Client Certificate Auth
    role: User
    trust_anchor:
        realm: user-ca

=head3 Static role, extended user information from CN

Querys the given connector with the full DN as argument, expects a hash
that contains at least the key I<username>, all other keys are made
available in the C<userinfo> structure (e.g. I<realname> and I<emailaddress>).

    type: ClientX509
    label: Client Certificate Auth
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
    label: Client Certificate Auth
    user@: connector:my.user.info.source
    trust_anchor:
        realm: user-ca
