package OpenXPKI::Server::Workflow::Validator::CheckLDAPData;

use strict;
use warnings;

use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use Net::LDAP;
use Template;
use OpenXPKI::Exception;
use Data::Dumper;

my @parameters = qw(
  ldap_server
  ldap_port
  ldap_userdn
  ldap_basedn

  ldap_attributes
  ldap_attrmap
  ldap_timelimit
  ldap_attribute
  condition
);

__PACKAGE__->mk_accessors(@parameters);

sub _init {
    my ( $self, $params ) = @_;

    # propagate workflow condition parametrisation to our object
    foreach my $arg (@parameters) {
        if ( defined $params->{$arg} ) {
            $self->$arg( $params->{$arg} );
        }
    }
    if (
        !(
               defined $self->ldap_server()
            && defined $self->ldap_port()
            && defined $self->ldap_userdn()
            && defined $self->ldap_basedn()
        )
      )
    {
        ##! 16: 'error: not all params defined'
        configuration_error
          "Missing parameters in ",
          "declaration of condition ", $self->name;
    }
}

sub validate {
    ##! 1: 'start'
    my ( $self, $wf, $creator, $auth1_id, $auth2_id ) = @_;

    my $context = $wf->context();
    my $errors  = $context->param('__error');
    $errors ||= [];

    my @ldap_attribs = split( /,/, $self->ldap_attributes() );
    my %ldap_attrmap =
      map { split(/\s*[=-]>\s*/) }
      split( /\s*,\s*/, $self->ldap_attrmap() );

    ##! 2: 'connecting to ldap server ' . $ldap_server . ':' . $ldap_port
    my $ldap = Net::LDAP->new(
        $self->ldap_server,
        port    => $self->ldap_port,
        onerror => undef,
    );

    ##! 2: 'ldap object created'
    # TODO: maybe use TLS ($ldap->start_tls())?

    if ( !defined $ldap ) {
        OpenXPKI::Exception->throw(
            message =>
'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_CONNECTION_FAILED',
            params => {
                'LDAP_SERVER' => $self->ldap_server,
                'LDAP_PORT'   => $self->ldap_port,
            },
            log => {
                logger   => CTX('log'),
                priority => 'error',
                facility => 'monitor',
            },
        );
    }

    my $mesg = $ldap->bind( $self->ldap_userdn, password => $self->ldap_pass );
    if ( $mesg->is_error() ) {
        OpenXPKI::Exception->throw(
            message =>
'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_BIND_FAILED',
            params => {
                ERROR      => $mesg->error(),
                ERROR_DESC => $mesg->error_desc(),
            },
            log => {
                logger   => CTX('log'),
                priority => 'error',
                facility => 'monitor',
            },
        );
    }
    ##! 2: 'ldap->bind() done'

    my $key = $self->param('search_key');
    my $svc = $self->param('search_value_context');

    # the search_value_context may be either the name of
    # a context parameter to fetch or a string parseable
    # by the Template module (e.g:
    #   "some text with [% embeded_field %]").
    my $svcparsed = '';
    my $tt        = Template->new();
    $tt->process( \$svc, $context->param(), \$svcparsed );
    my $value = '';
    if ( $svc eq $svcparsed ) {
        $value = $context->param( $self->param('search_value_context') );
    }
    else {
        $value = $svcparsed;
    }
    ##! 128: "svc=$svc, svcparsed=$svcparsed, value=$value"

    $mesg = $ldap->search(
        base      => $self->ldap_basedn,
        scope     => 'sub',
        filter    => "($key=$value)",
        attrs     => \@ldap_attribs,
        timelimit => $self->ldap_timelimit,
    );
    if ( $mesg->is_error() ) {
        OpenXPKI::Exception->throw(
            message =>
'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_SEARCH_FAILED',
            params => {
                ERROR      => $mesg->error(),
                ERROR_DESC => $mesg->error_desc(),
            },
            log => {
                logger   => CTX('log'),
                priority => 'error',
                facility => 'monitor',
            },
        );
    }
    ##! 2: 'ldap->search() done'
    ##! 16: 'mesg->count: ' . $mesg->count

    if (   $creator eq $auth1_id
        or $creator  eq $auth2_id
        or $auth1_id eq $auth2_id )
    {
        ##! 1: 'SCOTTY - creator, auth1 and auth2 not unique'
        push @{$errors},
          ['I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_SCPU_INVALID_AUTHID'];
    }
    else {

        foreach my $u ( $creator, $auth1_id, $auth2_id ) {
            next if exists $dbg::cfg->{ldap_ids}->{$u};
            ##! 1: 'SCOTTY - id ' .$u. ' not in (pseudo) LDAP'
            push @{$errors},
              [
                'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_SCPU_INVALID_AUTHID',
                'User = ' . $u,
              ];
        }
    }

    if ( scalar @{$errors} ) {
        CTX('log')->log(
            MESSAGE  => "Errors valdiating authorizing persons",
            PRIORITY => 'error',
            FACILITY => 'system',
        );

        #		validation_error($errors->[scalar @{$errors} -1]);
        validation_error( Dumper($errors) );
        return -1;
    }

    return 1;
}

1;
__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::CheckLDAPData

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="CheckLDAPData"
           class="OpenXPKI::Server::Workflow::Validator::CheckLDAPData">
      <param name="min" value="rsaEncryption: 2048, dsaEncryption: 2048, id-ecPu
blicKey: 191"/>
      <param name="max" value="rsaEncryption: 4096, dsaEncryption: 2048, id-ecPu
blicKey: 800"/>
      <param name="fail_on_unknown_algorithm" value="1"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator checks the length of the public key in the CSR.
It can be configured to use both a minimum (required) and maximum (optional)
value for the key length in bits for different algorithm.

The example above would allow you to make sure that RSA keys are between
2048 and 4096 bits, DSA keys exactly 2048 bits and EC-DSA keys between
191 and 800 bits. The validator would fail on any other algorithm (this
can be used to force people to only use RSA keys, for example).
