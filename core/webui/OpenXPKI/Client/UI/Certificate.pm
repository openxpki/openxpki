# OpenXPKI::Client::UI::Certificate
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Certificate;

use Moose; 
use Data::Dumper;
use OpenXPKI::DN;

extends 'OpenXPKI::Client::UI::Result';

sub BUILD {    
    my $self = shift;       
}

=head2 init_search 

Render the search form
#TODO - preset parameters

=cut
sub init_search {
    
    my $self = shift;
    my $args = shift;
    
    $self->_page({
        label => 'Certificate Search',
        description => 'Search for certificates here, all fields are exact match but you can use asterisk or question mark as wildcard. 
        The SAN requires the type of san to be prefixed with a colon, e.g. DNS:www2.openxpki.org. 
        The states VALID/EXPIRED are ISSUED plus a check if inside/outside their validity window.',
    });
        
    my $profile = $self->send_command( 'get_cert_profiles' );
    
    # TODO Sorting / I18
    my @profile_names = keys %{$profile};
    @profile_names = sort @profile_names;
    
    my @profile_list = map { $_ = {'value' => $_, 'label' => $profile->{$_}->{label}} } @profile_names ;
    unshift @profile_list, { value => "", label => "all" };
    
    my @states = (
        { label => 'all', value => ''},        
        { label => 'ISSUED', value => 'ISSUED'},
        { label => 'VALID', value => 'VALID'},
        { label => 'EXPIRED', value => 'EXPIRED'},
        { label => 'REVOKED', value => 'REVOKED'},
        { label => 'CRL PENDING', value => 'CRL_ISSUANCE_PENDING'},
    );
    
    $self->_result()->{main} = [        
        {   type => 'form',
            action => 'certificate!search',
            content => {
                title => '',
                submit_label => 'search now',
                fields => [
                { name => 'subject', label => 'Subject', type => 'text', is_optional => 1 },
                { name => 'san', label => 'SAN', type => 'text', is_optional => 1 },
                { name => 'status', label => 'status', type => 'select', is_optional => 1, options => \@states },                        
                { name => 'profile', label => 'Profile', type => 'select', is_optional => 1, options => \@profile_list },
                { name => 'meta_requestor', label => 'Requestor', type => 'text', is_optional => 1 },
                { name => 'meta_email', label => 'Req. eMail', type => 'text', is_optional => 1 },
                ]
        }},
        {   type => 'text', content => {
            headline => 'My little Headline',
            paragraphs => [{text=>'Paragraph 1'},{text=>'Paragraph 2'}]
        }},    
    ];
        
    return $self;
}


sub init_detail {

    
    my $self = shift;
    my $args = shift;
    
    my $cert_identifier = $self->param('identifier');     
    my $cert = $self->send_command( 'get_cert', { FORMAT => 'HASH', IDENTIFIER => $cert_identifier });
    
    $self->logger()->debug("result: " . Dumper $cert);
    
    $self->_page({
        label => 'Certificate Information',   
        shortlabel => $cert->{BODY}->{SUBJECT_HASH}->{CN},     
    });
      
      
    if ($cert->{STATUS} eq 'ISSUED' && $cert->{BODY}->{NOTAFTER} < time()) {
        $cert->{STATUS} = 'EXPIRED';
    }      
      
    my @fields = (
        { label => 'Subject', value => $cert->{BODY}->{SUBJECT} },
        { label => 'Serial', value => $cert->{BODY}->{SERIAL_HEX} },
        { label => 'Issuer', value => $cert->{BODY}->{ISSUER} },              
        { label => 'not before', value => $cert->{BODY}->{NOTBEFORE}, format => 'timestamp'  },
        { label => 'not after', value => $cert->{BODY}->{NOTAFTER}, format => 'timestamp' },
        { label => 'Status', value => $cert->{STATUS}, format => 'certstatus' },
    );                     
   
    my @buttons = {action => "workflow!index!wf_type!I18N_OPENXPKI_WF_TYPE_CHANGE_METADATA!cert_identifier!$cert_identifier", label=>'metadata'};
    push @buttons, {action => "workflow!index!wf_type!I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST!cert_identifier!$cert_identifier", label=>'revoke'}
        if ($cert->{STATUS} eq 'ISSUED');
                         
    push @buttons, {action => "workflow!index!wf_type!I18N_OPENXPKI_WF_TYPE_CERTIFICATE_RENEWAL_REQUEST!org_cert_identifier!$cert_identifier", label=>'renew'}
        if ($cert->{STATUS} eq 'ISSUED' || $cert->{STATUS} eq 'EXPIRED');
                
    $self->_result()->{main} = [{
        type => 'keyvalue',
        content => {
            label => '',
            description => '',
            data => \@fields,
        }},           
        {
        type => 'form',
        action => 'workflow!index!wf_type!I18N_OPENXPKI_WF_TYPE_CHANGE_METADATA',        
        content => {            
            buttons => \@buttons,
            fields => [                 
                { name => 'cert_identifier', type => 'hidden', value => $cert_identifier } 
            ]
        }}
    ]; 
    
}



sub init_detail {

    
    my $self = shift;
    my $args = shift;
    
    my $cert_identifier = $self->param('identifier');
    
         
}


=head2 action_search 

Handle search requests and display the result as grid

=cut

sub action_search {
    
    
    my $self = shift;
    my $args = shift;
    
    my $query = { LIMIT => 100 }; # Safety barrier
    foreach my $key (qw(subject issuer_dn profile)) {
        my $val = $self->param($key);    
        if (defined $val && $val ne '') {
            $query->{uc($key)} = $val;     
        }
    }
    
    if (my $status = $self->param('status')) {
        if ($status eq 'EXPIRED') {
            $status = 'ISSUED';
            $query->{NOTAFTER} = time();
        } elsif ($status eq 'VALID') {
            $status = 'ISSUED';
            $query->{VALID_AT} = time();
        }
        $query->{STATUS} = $status;
    } 
    
    my @attr;
    if (my $val = $self->param('san')) {
        push @attr, ['subject_alt_name', $val ];       
    }
    
    $self->logger()->debug("query : " . Dumper $self->cgi()->param());
    
    foreach my $key (qw(meta_requestor meta_email)) {
        my $val = $self->param($key);    
        if (defined $val && $val ne '') {
            push @attr, [ $key , $val ];     
        }
    }
    
    if (scalar @attr) {
        $query->{CERT_ATTRIBUTES} = \@attr;
    }
        
    $self->logger()->debug("query : " . Dumper $query);
            
    my $search_result = $self->send_command( 'search_cert', $query );
    return $self unless(defined $search_result);
    
    $self->logger()->debug( "search result: " . Dumper $search_result);

    $self->_page({
        label => 'Certificate Search - Results',
        shortlabel => 'Results',
        description => 'Here are the results of the swedish jury:',
    });
    
    my $i = 1;
    my @result;
    foreach my $item (@{$search_result}) {
        $item->{STATUS} = 'EXPIRED' if ($item->{STATUS} eq 'ISSUED' && $item->{NOTAFTER} < time());
        
        push @result, [
            $item->{CERTIFICATE_SERIAL},
            $item->{SUBJECT},
            $item->{EMAIL} || '',
            $item->{NOTBEFORE},
            $item->{NOTAFTER},
            $item->{ISSUER_DN},
            $item->{IDENTIFIER},
            lc($item->{STATUS}),
            $item->{IDENTIFIER},                    
        ]
    }
 
    $self->logger()->trace( "dumper result: " . Dumper @result);
    
    $self->add_section({
        type => 'grid',
        processing_type => 'all',
        content => {
            header => 'Grid-Headline',
            actions => [{   
                path => 'certificate!download!identifier!{identifier}',
                label => 'Download as PEM',
                icon => 'download'
            },{   
                path => 'certificate!detail!identifier!{identifier}',
                label => 'Detailed Information',
                icon => 'view',
                target => 'tab',
            },{   
                path => 'certificate!workflows!identifier!{identifier}',
                label => 'Related workflows',
                icon => 'view',
                target => 'tab',
            }],            
            columns => [                        
                { sTitle => "serial" },
                { sTitle => "subject" },
                { sTitle => "email"},
                { sTitle => "notbefore", format => 'timestamp' },
                { sTitle => "notafter", format => 'timestamp' },
                { sTitle => "issuer"},
                { sTitle => "identifier"},
                { sTitle => "_status"},                
            ],
            data => \@result            
        }
    });
    return $self;
    
}
    
    
1;