# OpenXPKI::Client::UI::Bootstrap
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Bootstrap;

use Moose;
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';

sub init_structure {

    my $self = shift;
    my $session = $self->_client()->session();
    my $user = $session->param('user') || undef;

    if ($session->param('is_logged_in') && $user) {
        $self->_result()->{user} = $user;
        $self->_init_structure_for_user( $user );
    }

    if (!$self->_result()->{structure}) {
        $self->_result()->{structure} =
        [{
            key => 'logout',
            label =>  'Clear Login',
            entries =>  []
        }]
    }

    return $self;

}

sub _init_structure_for_user {

    my $self = shift;
    my $user = shift;

    $self->_result()->{structure} =
    [{
         key=> 'home',
         label=>  'Home',
         entries=>  [
             {key=> 'home!index', label =>  "Home"},
             {key=> 'home!task', label =>  "My tasks"},
             {key=> 'home!workflow',label =>  "My workflows"},
             {key=> 'home!certificate',label =>  "My certificates"} ,
         ]
      },

      {
         key=> 'request',
         label=>  'Request',
         entries=>  [
              {key=> 'workflow!index!wf_type!certificate_signing_request_v2', label =>  "Request new certificate"},
              #{key=> 'workflow!index!wf_type!certificate_renewal_request_v2', label =>  "Request renewal"},
              {key=> 'workflow!index!wf_type!certificate_revocation_request_v2', label =>  "Request revocation"} ,
         ]
      },
      {
         key=> 'pkiadm',
         label=>  'PKI Operation',
         entries=>  [
             {key=> 'workflow!index!wf_type!change_metadata', label =>  "Change metadata"},
             {key=> 'workflow!index!wf_type!crl_issuance', label =>  "Issue CRL"},
             {key=> 'secret!index', label =>  "Manage Secrets"},
             {key=> 'information!process',label =>  "Process Information"}
         ]
      },
      {
         key=> 'info',
         label=>  'Information',
         entries=>  [
             {key=> 'information!issuer', label =>  "CA certificates"},
             {key=> 'information!crl',label =>  "Revocation lists"},
             #{key=> 'information!policy',label =>  "Pollicy documents"}
         ]
      },
      {
          key=> 'certificate!search',
          label =>  "Certificates",
          entries=> []
      },
      {
         key => 'workflow!search',
         label =>  "Workflows",
         entries=>  []
      }
   ];


   return $self;
}

sub init_error {

    my $self = shift;
    my $args = shift;

    $self->_result()->{main} = [{
        type => 'text',
        content => {
            headline => 'Ooops - something went wrong',
            paragraphs => [{text=>'Something is wrong here'}]
        }
    }];

    return $self;
}
1;
