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
    
    if ($user) {
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
             {key=> 'my_tasks', label =>  "My tasks"},
             {key=> 'my_workflows',label =>  "My workflows"},  
             {key=> 'my_certificates',label =>  "My certificates"} , 
             {key=> 'key_status',label =>  "Key status"}  
         ]   
      },
      
      {
         key=> 'request',
         label=>  'Request',
         entries=>  [
             {key=> 'request_cert', label =>  "Request new certificate"},
             {key=> 'request_renewal',label =>  "Request renewal"},  
             {key=> 'request_revocation',label =>  "Request revocation"} , 
             {key=> 'issue_clr',label =>  "Issue CLR"}  
         ]   
      },
      
      {
         key=> 'info',
         label=>  'Information',
         entries=>  [
             {key=> 'ca_cetrificates', label =>  "CA certificates"},
             {key=> 'revocation_lists',label =>  "Revocation lists"},  
             {key=> 'policy_docs',label =>  "Pollicy documents"}   
         ]   
      },
      
      {
         key=> 'search',
         label=>  'Search',
         entries=>  [
             {key=> 'search!certificate', label =>  "Certificates"},
             {key=> 'search!workflow',label =>  "Workflows"} 
         ]   
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