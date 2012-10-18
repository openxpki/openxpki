package OpenXPKI::Server::Workflow::Validator::SmartcardPINUnblockAuthIDs;

use strict;
use warnings;

use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use Net::LDAP;
use Data::Dumper;

my @required_parameters = qw(
  ldap_server
  ldap_port
  ldap_userdn
  ldap_pass
  ldap_basedn
  ldap_timelimit
  search_key
);

my @parameters = @required_parameters;

__PACKAGE__->mk_accessors(@parameters);

sub _init {
    my ( $self, $params ) = @_;

    # propagate workflow condition parametrisation to our object
    foreach my $arg (@parameters) {
        if ( defined $params->{$arg} ) {
            $self->$arg( $params->{$arg} );
        }
    }
#    foreach (@required_parameters) {
#        if ( not defined $self->$_() ) {
#            ##! 16: 'error: not all required parameters defined'
#            configuration_error(
#              "Missing parameters in ",
#              "declaration of condition ", $self->name);
#        }
#    }
}

sub validate {
    ##! 1: 'start'
    my ( $self, $wf ) = @_;

    my $context = $wf->context();
    my $errors  = $context->param('__error');

    my $creator = $context->param('creator');
    my $auth1_id = $context->param('auth1_id');
    my $auth2_id = $context->param('auth2_id');

    $errors ||= [];

    if (   $creator eq $auth1_id
        or $creator  eq $auth2_id
        or $auth1_id eq $auth2_id )
    {
        ##! 1: 'SCOTTY - creator, auth1 and auth2 not unique'
        push @{$errors},
          ['I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_SCPU_INVALID_AUTHID'];
    }
    else {

        ##! 2: 'connecting to ldap server ' . $self->ldap_server . ':' . $self->ldap_port
        my $ldap = Net::LDAPS->new(
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

        my $mesg =
          $ldap->bind( $self->ldap_userdn, password => $self->ldap_pass );
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

        foreach my $u ( $auth1_id, $auth2_id ) {
            my $filter = '(' . $self->search_key . '=' . $u . ')';
            ##! 2: 'ldap->search() with filter ' . $filter
            $mesg = $ldap->search(
                base      => $self->ldap_basedn,
                scope     => 'sub',
                filter    => $filter,
                timelimit => $self->ldap_timelimit,
            );
            ##! 16: "mesg returned from LDAP for auth $u: " . Dumper($mesg)
            if ( $mesg->count != 1 ) {
                push @{$errors},
                  [
'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_SCPU_INVALID_AUTHID',
                    'User = ' . $u,
                  ];
            }
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

OpenXPKI::Server::Workflow::Validator::SmartcardPINUnblockAuthIDs

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="SmartcardPINUnblockAuthIDs"
           class="OpenXPKI::Server::Workflow::Validator::SmartcardPINUnblockAuthIDs">
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
