# OpenXPKI::Client::UI::Certificate
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Certificate;

use Moose;
use Data::Dumper;
use OpenXPKI::DN;
use Math::BigInt;
use Digest::SHA qw(sha1_base64);


has __default_grid_head => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    
    default => sub { return [
        { sTitle => "Serial", sortkey => 'CERTIFICATE.CERTIFICATE_SERIAL' },
        { sTitle => "Subject", sortkey => 'CERTIFICATE.SUBJECT' },
        { sTitle => "Status", format => 'certstatus', sortkey => 'CERTIFICATE.STATUS' },
        { sTitle => "Notbefore", format => 'timestamp', sortkey => 'CERTIFICATE.NOTBEFORE' },
        { sTitle => "Notafter", format => 'timestamp', sortkey => 'CERTIFICATE.NOTAFTER' },
        { sTitle => "Issuer", sortkey => 'CERTIFICATE.ISSUER_DN'},
        { sTitle => "Identifier", sortkey => 'CERTIFICATE.IDENTIFIER'},
        { sTitle => 'identifier', bVisible => 0 },
        { sTitle => "_className"},
    ]; }
);

has __default_grid_row => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { return [
        { source => 'certificate', field => 'CERTIFICATE_SERIAL' },
        { source => 'certificate', field => 'SUBJECT' },
        { source => 'certificate', field => 'STATUS' },
        { source => 'certificate', field => 'NOTBEFORE' },
        { source => 'certificate', field => 'NOTAFTER' },
        { source => 'certificate', field => 'ISSUER_DN' },
        { source => 'certificate', field => 'IDENTIFIER' },
        { source => 'certificate', field => 'IDENTIFIER' },
        { source => 'certificate', field => 'CERTSTATUS' },
    ]; }
);

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
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_LABEL',
        description => '',  
    });

    my $profile = $self->send_command( 'list_used_profiles' );

    # TODO Sorting / I18

    my @profile_list = sort { $a->{label} cmp $b->{label} } @{$profile};

    my @states = (
        { label => 'I18N_OPENXPKI_UI_CERT_STATUS_ISSUED', value => 'ISSUED'},
        { label => 'I18N_OPENXPKI_UI_CERT_STATUS_VALID', value => 'VALID'},
        { label => 'I18N_OPENXPKI_UI_CERT_STATUS_EXPIRED', value => 'EXPIRED'},
        { label => 'I18N_OPENXPKI_UI_CERT_STATUS_REVOKED', value => 'REVOKED'},
        { label => 'I18N_OPENXPKI_UI_CERT_STATUS_CRL_ISSUANCE_PENDING', value => 'CRL_ISSUANCE_PENDING'},
    );
    
    my $preset;
    if ($args->{preset}) {
        $preset = $args->{preset};    
    } elsif (my $queryid = $self->param('query')) {
        my $result = $self->_client->session()->param('query_cert_'.$queryid);
        $preset = $result->{input};
    }
    
    my @fields = (
        { name => 'subject', label => 'Subject', type => 'text', is_optional => 1, value => $preset->{subject} },
        { name => 'san', label => 'SAN', type => 'text', is_optional => 1, value => $preset->{san} },
        { name => 'status', label => 'status', type => 'select', is_optional => 1, prompt => 'all', options => \@states, , value => $preset->{status} },
        { name => 'profile', label => 'Profile', type => 'select', is_optional => 1, prompt => 'all', options => \@profile_list, value => $preset->{profile} },        
   );

    my $attributes = $self->_client->session()->param('certsearch')->{default}->{attributes};
    if (defined $attributes && (ref $attributes eq 'ARRAY')) {
        my @attrib;
        foreach my $item (@{$attributes}) {
            push @attrib, { value => $item->{key}, label=> $item->{label} };                    
        }
        push @fields, {
            name => 'attributes', 
            label => 'Metadata', 
            'keys' => \@attrib,                  
            type => 'text',
            is_optional => 1, 
            'clonable' => 1,
            'value' => $preset->{attributes} || [],
        } if (@attrib);
    }

    $self->add_section({
        type => 'form',
        action => 'certificate!search',
        content => {
           description => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_DESC',
           title => '',
           submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SUBMIT_LABEL',
           fields => \@fields
        }},        
    );
    
    $self->add_section({
        type => 'form',
        action => 'certificate!find',
        content => {
           title => '',
           description => 'I18N_OPENXPKI_UI_CERTIFICATE_BY_IDENTIFIER_OR_SERIAL',
           submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SUBMIT_LABEL',
           fields => [
               { name => 'cert_identifier', label => 'I18N_OPENXPKI_UI_CERTIFICATE_IDENTIFIER', type => 'text', is_optional => 1, value => $preset->{cert_identifier} },
               { name => 'cert_serial', label => 'I18N_OPENXPKI_UI_CERTIFICATE_SERIAL', type => 'text', is_optional => 1, value => $preset->{cert_serial} },              
           ]
        }},        
    );

    return $self;
}

=head2 init_result

Load the result of a query, based on a query id and paging information
 
=cut
sub init_result {

    my $self = shift;
    my $args = shift;
        
    my $queryid = $self->param('id');
    my $limit = $self->param('limit') || 25;
    
    
    my $startat = $self->param('startat') || 0; 
    
    # Safety rule
    if ($limit > 500) {  $limit = 500; }

    # Load query from session
    my $result = $self->_client->session()->param('query_cert_'.$queryid);

    # result expired or broken id
    if (!$result || !$result->{count}) {        
        $self->set_status('Search result expired or empty!','error');
        return $self->init_search();        
    }

    # Add limits
    my $query = $result->{query};    
    $query->{LIMIT} = $limit;
    $query->{START} = $startat;
    
    if (!$query->{ORDER}) {
        $query->{ORDER} = 'CERTIFICATE.NOTBEFORE';
        if (!defined $query->{REVERSE}) {
            $query->{REVERSE} = 1;
        }
    }

    $self->logger()->debug( "persisted query: " . Dumper $result);

    my $search_result = $self->send_command( 'search_cert', $query );
    
    $self->logger()->trace( "search result: " . Dumper $search_result);

    $self->_page({
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_RESULT_LABEL',       
        description => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_RESULT_DESC',
    });

    my $pager;
    if ($startat != 0 || @{$search_result} == $limit) {
        $pager = $self->__render_pager( $result, { limit => $limit, startat => $startat } );
    }

    my $body = $result->{column};
    $body = $self->__default_grid_row() if(!$body);
    
    my $header = $result->{header};
    $header = $self->__default_grid_head() if(!$header);

    my @result = $self->__render_result_list( $search_result, $body );
    
    $self->logger()->trace( "dumper result: " . Dumper @result);

    $self->add_section({
        type => 'grid',
        className => 'certificate',
        content => {
            actions => [{
                path => 'certificate!detail!identifier!{identifier}',
                label => 'Download',
                icon => 'download',
                target => 'modal'
            }], 
            columns => $header,
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            pager => $pager,
            buttons => [
                { label => 'I18N_OPENXPKI_UI_SEARCH_RELOAD_FORM', page => 'certificate!search!query!' .$queryid },
                { label => 'I18N_OPENXPKI_UI_SEARCH_REFRESH', page => 'redirect!certificate!result!id!' .$queryid },
                { label => 'I18N_OPENXPKI_UI_SEARCH_NEW_SEARCH', page => 'certificate!search'},
            ]
        }
    });

    return $self;

}


=head2 init_pager

Similar to init_result but returns only the data portion of the table as
partial result.

=cut

sub init_pager {
    
    my $self = shift;
    my $args = shift;
        
    my $queryid = $self->param('id');
    
    # Load query from session
    my $result = $self->_client->session()->param('query_cert_'.$queryid);

    # result expired or broken id
    if (!$result || !$result->{count}) {
        $self->set_status('Search result expired or empty!','error');
        return $self->init_search();               
    }

    # will be removed once inline paging works
    my $startat = $self->param('startat'); 

    my $limit = $self->param('limit') || 25;  
    if ($limit > 500) {  $limit = 500; }
    
    $startat = int($startat / $limit) * $limit;

    # Add limits
    my $query = $result->{query};
    $query->{LIMIT} = $limit;
    $query->{START} = $startat;
    
    if ($self->param('order')) {
        $query->{ORDER} = uc($self->param('order'));
    }
    
    if (defined $self->param('reverse')) {
        $query->{REVERSE} = $self->param('reverse');
    }

    $self->logger()->debug( "persisted query: " . Dumper $result);
    $self->logger()->debug( "executed query: " . Dumper $query);

    my $search_result = $self->send_command( 'search_cert', $query );
    
    $self->logger()->trace( "search result: " . Dumper $search_result);
     
    my $body = $result->{column};
    $body = $self->__default_grid_row() if(!$body);
     
    my @result = $self->__render_result_list( $search_result, $body ); 
        
    $self->logger()->trace( "dumper result: " . Dumper @result);

    $self->_result()->{_raw} = {
        _returnType => 'partial',
        data => \@result,
    };
    
    return $self;
}
=head2 init_mine

my certificates view, finds certificates based on the current logged in userid
 
=cut
sub init_mine {

    my $self = shift;
    my $args = shift;
           
    my $limit = $self->param('limit') || 25;
    
    # Safety rule
    if ($limit > 500) {  $limit = 500; }
    
    # will be removed once inline paging works
    my $startat = $self->param('startat') || 0; 
    
    my $query = {          
        CERT_ATTRIBUTES => [{ 
            KEY => 'system_cert_owner', 
            VALUE =>  $self->_session->param('user')->{name}, 
            OPERATOR => 'EQUAL'
        }],
        ORDER => 'CERTIFICATE.NOTBEFORE',
        REVERSE => 1,
    };

    $self->logger()->debug( "search query: " . Dumper $query);

    my $search_result = $self->send_command( 'search_cert', { %$query, ( LIMIT => $limit, START => $startat ) } );
    
    my $result_count = scalar @{$search_result};
    my $pager;
    if ($result_count == $limit) {
        my %count_query = %{$query};
        delete $count_query{ORDER};
        delete $count_query{REVERSE};
        
        $result_count = $self->send_command( 'search_cert_count', \%count_query );

        my $queryid = $self->__generate_uid();
        my $_query = {
            'id' => $queryid,
            'type' => 'certificate',
            'count' => $result_count,
            'query' => $query,
        };
        $self->_client->session()->param('query_cert_'.$queryid, $_query );
        $pager = $self->__render_pager( $_query, { limit => $limit, startat => $startat } )

    } 
    
    $self->logger()->trace( "search result: " . Dumper $search_result);

    $self->_page({
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_MINE_LABEL',        
        description => 'I18N_OPENXPKI_UI_CERTIFICATE_MINE_DESC',
    });
    
    my @result = $self->__render_result_list( $search_result, $self->__default_grid_row() );
     
    $self->logger()->trace( "dumper result: " . Dumper @result);
    
    $self->add_section({
        type => 'grid',
        className => 'certificate',
        content => {
            actions => [{
                path => 'certificate!detail!identifier!{identifier}',
                label => 'Download',
                icon => 'download',
                target => 'modal'
            }], 
            columns => $self->__default_grid_head(),
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',            
            pager => $pager,
        }
    });

    return $self;

}

=head2 init_detail 

Show details on the certificate, includes basic certificate information,
status, issuer and links to download chains and related workflow. Designed to 
be shown in a modal popup.

=cut

sub init_detail {

    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');

    # empty submission
    if (!$cert_identifier) {
        $self->redirect('certificate!search');                
        return;        
    }

    my $cert = $self->send_command( 'get_cert', {  IDENTIFIER => $cert_identifier, FORMAT => 'DBINFO' });
    $self->logger()->debug("result: " . Dumper $cert);
    
    my $cert_attribute = $self->send_command( 'get_cert_attributes', {  IDENTIFIER => $cert_identifier, ATTRIBUTE => 'subject_%' });
    $self->logger()->debug("result: " . Dumper $cert_attribute);
            
    my %dn = OpenXPKI::DN->new( $cert->{SUBJECT} )->get_hashed_content();
    
    $self->_page({
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_DETAIL_LABEL',
        shortlabel => $dn{CN}[0]
    });


    my @fields = ( { label => 'Subject', value => $cert->{SUBJECT} } );
     
    if ($cert_attribute && $cert_attribute->{subject_alt_name}) {        
        #my $cert_attribute->{subject_alt_name};
        push @fields, { label => 'Subject Alt. Name', value => $cert_attribute->{subject_alt_name}, 'format' => 'ullist' };
    } 
        
    # check if this is a entity certificate from the current realm
    my $is_local_entity = 0;
    if ($cert->{CSR_SERIAL} && $cert->{PKI_REALM} eq $self->_session->param('pki_realm')) {
        $self->logger()->debug("cert is local entity");
        $is_local_entity = 1;
    }
    
    if ($is_local_entity) {
        my $cert_profile  = $self->send_command( 'get_profile_for_cert', {  IDENTIFIER => $cert_identifier }, 1);
        if ($cert_profile) {
            push @fields, { label => 'Profile', value => $cert_profile };    
        }   
    }

    push @fields, (
        { label => 'Serial', value => '0x'.$cert->{CERTIFICATE_SERIAL_HEX} },
        { label => 'Identifier', value => $cert_identifier },
        { label => 'not before', value => $cert->{NOTBEFORE}, format => 'timestamp'  },
        { label => 'not after', value => $cert->{NOTAFTER}, format => 'timestamp' },
        { label => 'Status', value => { label => 'I18N_OPENXPKI_UI_CERT_STATUS_'.$cert->{STATUS} , value => $cert->{STATUS} }, format => 'certstatus' },
        { label => 'Issuer', format => 'link', value => { label => $cert->{ISSUER_DN}, page => 'certificate!chain!identifier!'. $cert_identifier } },
    );

    # for i18n parser I18N_OPENXPKI_CERT_ISSUED CRL_ISSUANCE_PENDING I18N_OPENXPKI_CERT_REVOKED I18N_OPENXPKI_CERT_EXPIRED

    # was in info, bullet list for downloads
    my $base =  $self->_client()->_config()->{'scripturl'} . "?page=certificate!download!identifier!$cert_identifier!format!";
    my $pattern = '<li><a href="'.$base.'%s" target="_blank">%s</a></li>';

    push @fields, { label => 'I18N_OPENXPKI_UI_DOWNLOAD_LABEL', value => [
        sprintf ($pattern, 'pem', 'I18N_OPENXPKI_UI_DOWNLOAD_PEM'),
        # core bug see #185 sprintf ($pattern, 'txt', 'I18N_OPENXPKI_UI_DOWNLOAD_TXT').
        sprintf ($pattern, 'der', 'I18N_OPENXPKI_UI_DOWNLOAD_DER'),
        sprintf ($pattern, 'pkcs7', 'I18N_OPENXPKI_UI_DOWNLOAD_PKCS7'),
        sprintf ($pattern, 'pkcs7!root!true', 'I18N_OPENXPKI_UI_DOWNLOAD_PKCS7_WITH_ROOT'),
        sprintf ($pattern, 'bundle', 'I18N_OPENXPKI_UI_DOWNLOAD_BUNDLE'),
        sprintf ($pattern, 'install', 'I18N_OPENXPKI_UI_DOWNLOAD_INSTALL'),
        '<li><a href="#/openxpki/certificate!text!identifier!'.$cert_identifier.'">I18N_OPENXPKI_UI_DOWNLOAD_SHOW_AS_TEXT</a></li>', ],        
        format => 'rawlist'
    };
    
    if ($is_local_entity) {
        
        $pattern = '<li><a href="#/openxpki/redirect!workflow!index!wf_type!%s!cert_identifier!'.$cert_identifier.'">%s</a></li>';
        
        my @actions;
        my $reply = $self->send_command ( "get_cert_actions", { IDENTIFIER => $cert_identifier });
        
        $self->logger()->debug("available actions for cert " . Dumper $reply);
        
        if (defined $reply->{workflow} && ref $reply->{workflow} eq 'ARRAY') {
            foreach my $item (@{$reply->{workflow}}) {
                push @actions, sprintf ($pattern, $item->{workflow}, $item->{label});
            }
        }
                
        push @fields, { 
            label => 'I18N_OPENXPKI_UI_CERT_ACTION_LABEL', 
            value => \@actions,
            format => 'rawlist'
        } if (@actions);
    }     
    
    push @fields, { label => 'I18N_OPENXPKI_UI_CERT_RELATED_LABEL', format => 'link', value => { 
        page => 'certificate!related!identifier!'.$cert_identifier,
        label => 'I18N_OPENXPKI_UI_CERT_RELATED_HINT'
    }};

    $self->add_section({
        type => 'keyvalue',
        content => {
            label => '',
            description => '',
            data => \@fields,
        }},
    );

}

=head2 init_text 

Show the PEM block as text in a modal

=cut

sub init_text {
    
    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');
    
    my $pem = $self->send_command ( "get_cert", {'IDENTIFIER' => $cert_identifier, 'FORMAT' => 'PEM' });
    
    $self->logger()->debug("Cert data: " . Dumper $pem);
    
    $self->_page({
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_DETAIL_LABEL',
        shortlabel => $cert_identifier,
    });
    
    $self->add_section({
        type => 'text',
        content => {
            label => '',
            description => '<code>'  . $pem . '</code>',
        }},
    );
    
    return $self;
    
    
}

=head2 init_chain

Show the full chain of a certificate (subjects only) with inline download
options for PEM/DER or browser install for each item of the chain.

=cut

sub init_chain {

    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');

    my $chain = $self->send_command ( "get_chain", { START_IDENTIFIER => $cert_identifier, OUTFORMAT => 'HASH', 'KEEPROOT' => 1 });

    $self->_page({
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_CHAIN_LABEL',
        shortlabel => 'I18N_OPENXPKI_UI_CERTIFICATE_CHAIN_LABEL',
    });

    # Download links
    my $base =  $self->_client()->_config()->{'scripturl'} . "?page=certificate!download!identifier!%s!format!%s";
    my $pattern = '<li><a href="'.$base.'" target="_blank">%s</a></li>';

    foreach my $cert (@{$chain->{CERTIFICATES}}) {

        my $dl = '<ul class="list-inline">'.
            sprintf ($pattern, $cert->{IDENTIFIER}, 'pem', 'I18N_OPENXPKI_UI_DOWNLOAD_SHORT_PEM').
            sprintf ($pattern, $cert->{IDENTIFIER}, 'der', 'I18N_OPENXPKI_UI_DOWNLOAD_SHORT_DER').
            sprintf ($pattern, $cert->{IDENTIFIER}, 'install', 'I18N_OPENXPKI_UI_DOWNLOAD_SHORT_INSTALL').
            '</ul>';

        $self->add_section({
            type => 'keyvalue',
            content => {
                label => '',
                description => '',
                data => [
                    { label => 'I18N_OPENXPKI_UI_CERTIFICATE_SUBJECT', format => 'link', 'value' => {
                       label => $cert->{SUBJECT}, page => 'certificate!detail!identifier!'.$cert->{IDENTIFIER} } },
                    { label => 'I18N_OPENXPKI_UI_CERTIFICATE_NOTBEFORE', value => $cert->{NOTBEFORE}, format => 'timestamp' },
                    { label => 'I18N_OPENXPKI_UI_CERTIFICATE_NOTAFTER', value => $cert->{NOTAFTER}, format => 'timestamp' },
                    { label => 'I18N_OPENXPKI_UI_DOWNLOAD_LABEL', value => $dl, format => 'raw' },
                ],
            }},
        );
    }

    return $self;

}

=head2 init_related

Show information related to the certificate, renders a key/value table with
a list of related workflows, owner, and metadata

=cut
sub init_related {


    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');

    my $cert = $self->send_command( 'get_cert', {  IDENTIFIER => $cert_identifier, FORMAT => 'DBINFO' });
    $self->logger()->debug("result: " . Dumper $cert);
    
    my %dn = OpenXPKI::DN->new( $cert->{SUBJECT} )->get_hashed_content();
    
    $self->_page({
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_RELATIONS_LABEL',
        shortlabel => $dn{CN}[0]
    });

    # run a workflow search using the given ids from the cert attributes
    my @wfid = ( 0 );
    foreach my $key (keys %{$cert->{CERT_ATTRIBUTES}}) {
        if ($key !~ m{ \A system_workflow }xs ) { 
            next; 
        }
        push @wfid, @{$cert->{CERT_ATTRIBUTES}->{$key}};
    }
    
    $self->logger()->debug("related workflows " . Dumper \@wfid);
    
    my $cert_workflows = $self->send_command( 'search_workflow_instances', {  SERIAL => \@wfid });

    $self->logger()->trace("workflow results" . Dumper $cert_workflows);


    my @result;
    foreach my $line (@{$cert_workflows}) {
        push @result, [
            $line->{'WORKFLOW.WORKFLOW_SERIAL'},
            $line->{'WORKFLOW.WORKFLOW_TYPE'},
            $line->{'WORKFLOW.WORKFLOW_STATE'},
            $line->{'WORKFLOW.WORKFLOW_SERIAL'},
        ];
    }
    
    $self->add_section({
        type => 'grid',
        className => 'workflow',
        content => {
            label => 'I18N_OPENXPKI_UI_CERTIFICATE_RELATED_WORKFLOW_LABEL',
            actions => [{
                path => 'workflow!load!wf_id!{serial}',
                label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                icon => 'view',
                target => 'tab',
            }],
            columns => [
                { sTitle => "I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL" },
                { sTitle => "I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL"},
                { sTitle => "I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL"},
                { sTitle => "serial", bVisible => 0 },
            ],
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
        }
    });
    return $self;


}

=head2 init_privkey

Prepare download of a private key, requests the password and export format
via form fields.

=cut
sub init_privkey {

    my $self = shift;
    my $cert_identifier = $self->param('identifier');

    $self->_page({
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_DOWNLOAD_PKEY_LABEL',
        description => 'I18N_OPENXPKI_UI_CERTIFICATE_DOWNLOAD_PKEY_DESC',
    });

    $self->add_section({
        type => 'form',
        action => 'certificate!privkey!identifier!' . $cert_identifier,
        content => {
           title => '',
           submit_label => 'download',
           fields => [
                { name => 'passphrase', label => 'Passphrase', type => 'password' },
                { name => 'format', label => 'Format', type => 'select', options => [
                    { value => 'PKCS12', label => 'PKCS12' },
                    { value => 'PKCS8_PEM', label => 'PKCS8 (PEM)' },
                    { value => 'PKCS8_DER', label => 'PKCS8 (DER)' },
                    # backend is broken for those, need fixing first
                    { value => 'OPENSSL_PRIVKEY', label => 'OpenSSL native' },                    
                    { value => 'JAVA_KEYSTORE', label => 'Java Keystore' }
                    ]
                },
            ]
        }});

    return $self;

}

=head2 init_download 

Handle download requests, required the cert_identifier and the expected format.
Redirects to init_detail if no format is given.

=cut
sub init_download {

    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');
    my $format = $self->param('format');

    # No format, call detail
    if (!$format) {

        return $self->init_detail();
         
    } elsif ($format eq 'pkcs7') {

        my $keeproot = $self->param('root') ? 1 : 0;
        my $pkcs7  = $self->send_command ( "get_chain", { START_IDENTIFIER => $cert_identifier, BUNDLE => 1, KEEPROOT => $keeproot });

        my $cert_info  = $self->send_command ( "get_cert", {'IDENTIFIER' => $cert_identifier, 'FORMAT' => 'HASH' });
        my $filename = $cert_info->{BODY}->{SUBJECT_HASH}->{CN}->[0] || $cert_info->{BODY}->{IDENTIFIER};

        print $self->cgi()->header( -type => 'application/pkcs7-mime', -expires => "1m", -attachment => "$filename.p7c" );
        print $pkcs7;
        exit;

    } elsif ($format eq 'bundle') {

        my $chain = $self->send_command ( "get_chain", { START_IDENTIFIER => $cert_identifier, OUTFORMAT => 'PEM', 'KEEPROOT' => 1 });
        $self->logger()->debug("chain info " . Dumper $chain );

        my $cert_info  = $self->send_command ( "get_cert", {'IDENTIFIER' => $cert_identifier, 'FORMAT' => 'HASH' });
        my $filename = $cert_info->{BODY}->{SUBJECT_HASH}->{CN}->[0] || $cert_info->{BODY}->{IDENTIFIER};

        my $output = '';
        for (my $i=0;$i<@{$chain->{CERTIFICATES}};$i++) {
            $output .= $chain->{SUBJECT}->[$i]. "\n". $chain->{CERTIFICATES}->[$i]."\n\n";
        }

        print $self->cgi()->header( -type => 'application/octet-string', -expires => "1m", -attachment => "$filename.bundle" );
        print $output;
        exit;


    } else {

        my $cert_info = $self->send_command ( "get_cert", {'IDENTIFIER' => $cert_identifier, 'FORMAT' => 'HASH' });
        $self->logger()->debug("cert info " . Dumper $cert_info );

        my $content_type = 'application/octet-string';
        my $filename = $cert_info->{BODY}->{SUBJECT_HASH}->{CN}->[0] || $cert_info->{BODY}->{IDENTIFIER};

        my $cert_format = 'DER';

        if ($format eq 'txt') {
            $content_type = 'text/plain';
            $cert_format = 'TXT';
            $filename .= '.txt';
        } elsif ($format eq 'pem') {
            $filename .= '.crt';
            $cert_format = 'PEM';
        } elsif ($format eq 'der') {
            $filename .= '.cer';
        } else {
            # Default is to send the certifcate for install in binary / der form
            $filename .= '.cer';
            if ($cert_info->{ISSUER_IDENTIFIER} eq $cert_info->{IDENTIFIER}) {
                $content_type = 'application/x-x509-ca-cert';
            } else {
                $content_type = 'application/x-x509-user-cert';
            }
        }

        my $cert = $self->send_command ( "get_cert", {'IDENTIFIER' => $cert_identifier, 'FORMAT' => $cert_format});

        print $self->cgi()->header( -type => $content_type, -expires => "1m", -attachment => $filename );
        print $cert;
        exit;

    }

    return $self;
}

=head2 init_parse 

not implemented 

receive a PEM encoded x509/pkcs10/pkcs7 block and output information.

=cut
sub init_parse {
    
    my $self = shift;
    my $args = shift;

    my $pem = $self->param('body');
    
    my @fields = ({
        label => 'Body',
        value => $pem
    });

    $self->_page({
        label => '',
        description => ''
    });

    $self->add_section({
        type => 'keyvalue',
        content => {
            label => 'Parsed Content',
            description => '',
            data => \@fields,
        }},
    );
    
    return $self;
    
}

=head2 action_autocomplete

Handle searches via autocomplete, shows only entity certificates

=cut

sub action_autocomplete {

    my $self = shift;
    my $args = shift;

    my $term = $self->param('query') || '';

    $self->logger()->debug( "autocomplete term: " . Dumper $term);

    my @result;    
    # If we see a string with length of 25 to 27 with only base64 chars 
    # we assume it is a cert identifier - this might fail in few cases
    # Note - we replace + and / by - and _ in our base64 strings!
    if ($term =~ /[a-zA-Z0-9-_]{25,27}/) {   
        $self->logger()->debug( "search for identifier: $term ");
        my $search_result = $self->send_command( 'get_cert', {
            IDENTIFIER => $term,
            FORMAT => 'DBINFO',
        });
        
        if ($search_result) {
            push @result, {
                value => $search_result->{IDENTIFIER},
                label => $self->_escape($search_result->{SUBJECT}),
                notbefore => $search_result->{NOTBEFORE},
                notafter => $search_result->{NOTAFTER}
            };
        }
    } 

    if (!@result) {
        my $search_result = $self->send_command( 'search_cert', {
            SUBJECT => "%$term%",
            VALID_AT => time(),
            STATUS => 'ISSUED',
            ENTITY_ONLY => 1        
        });
        
        $self->logger()->trace( "search result: " . Dumper $search_result);
    
        foreach my $item (@{$search_result}) {
            push @result, {
                value => $item->{IDENTIFIER},
                label => $self->_escape($item->{SUBJECT}),
                notbefore => $item->{NOTBEFORE},
                notafter => $item->{NOTAFTER}
            };
        }
    }
    
    $self->logger()->debug( "search result: " . Dumper \@result);

    $self->_result()->{_raw} = \@result;

    return $self;

}

=head2 action_find

Handle search requests for a single certificate by its identifier 

=cut

sub action_find {

    my $self = shift;
    my $args = shift;
    
    my $cert_identifier = $self->param('cert_identifier');
    if ($cert_identifier) {
        my $cert = $self->send_command( 'get_cert', {  IDENTIFIER => $cert_identifier, FORMAT => 'DBINFO' });
        if (!$cert) {
            $self->set_status('Unable to find a certificate with this identifier.','error');
            return $self->init_search();
        }
    } elsif (my $serial = $self->param('cert_serial')) {
        
        if ($serial =~ /[a-f]/ && substr($serial,0,2) ne '0x') {
            $serial = '0x' . $serial;
        }
        if (substr($serial,0,2) eq '0x') {
            # strip whitespace
            $serial =~ s/\s//g;
            my $sn = Math::BigInt->new( $serial );
            $serial = $sn->bstr();
        }
        my $search_result = $self->send_command( 'search_cert', {
            CERT_SERIAL => $serial,
            ENTITY_ONLY => 1
        });
        if (!$search_result) {
            $self->set_status('Unable to find a certificate with this serial number.','error');
            return $self->init_search();
        } elsif (scalar @{$search_result} != 1) {
            # this should not happen
            $self->set_status('Query ambigous - got more than one result on this serial number?!.','error');
            return $self->init_search();
        } else {            
            $cert_identifier = $search_result->[0]->{"IDENTIFIER"};
        } 
    } else {
        $self->set_status('Please enter either certificate identifier or certificate serial number.','error');
        return $self->init_search();
    }
    
    $self->redirect( 'certificate!detail!identifier!'.$cert_identifier );

}

=head2 action_search

Handle search requests and display the result as grid

=cut

sub action_search {


    my $self = shift;
    my $args = shift;

    my $query = { ENTITY_ONLY => 1 }; 
    my $input = {}; # store the input data the reopen the form later
    foreach my $key (qw(subject issuer_dn)) {
        my $val = $self->param($key);
        if (defined $val && $val ne '') {
            $query->{uc($key)} = '%'.$val.'%';
            $input->{$key} = $val;
        }
    }
    
    foreach my $key (qw(profile)) {
        my $val = $self->param($key);
        if (defined $val && $val ne '') {
            $input->{$key} = $val;
            $query->{uc($key)} = $val;
        }
    }
    
    if (my $status = $self->param('status')) {
        $input->{'status'} = $status;
        if ($status eq 'VALID') {
            $status = 'ISSUED';
            $query->{VALID_AT} = time();
        }
        $query->{STATUS} = $status;        
    }

    $self->logger()->debug("query : " . Dumper $self->cgi()->param());

    # Read the query pattern for extra attributes from the session 
    my $spec = $self->_client->session()->param('certsearch')->{default};
    my @attr = @{$self->__build_attribute_subquery( $spec->{attributes} )};        

    if (@attr) {
        $input->{attributes} = $self->__build_attribute_preset( $spec->{attributes} );
    }

    # Add san search to attributes
    if (my $val = $self->param('san')) {
        $input->{'san'} = $val;        
        push @attr, { KEY => 'subject_alt_name', VALUE => '%'.$val.'%' };
    }
    
    if (scalar @attr) {
        $query->{CERT_ATTRIBUTES} = \@attr;
    }
    
    $self->logger()->debug("query : " . Dumper $query);
    
    
    my $result_count = $self->send_command( 'search_cert_count', $query );
    
    # No results founds
    if (!$result_count) {
        $self->set_status('I18N_OPENXPKI_UI_SEARCH_HAS_NO_MATCHES','error');
        return $self->init_search({ preset => $input });
    }
    
    # check if there is a custom column set defined
    my ($header,  $body);    
    if ($spec->{cols} && ref $spec->{cols} eq 'ARRAY') {
        ($header, $body) = $self->__render_list_spec( $spec->{cols} );
    } else {
        $body = $self->__default_grid_row;
        $header = $self->__default_grid_head;
    }
    
    my $queryid = $self->__generate_uid();
    $self->_client->session()->param('query_cert_'.$queryid, {
        'id' => $queryid,
        'type' => 'certificate',
        'count' => $result_count,
        'query' => $query,
        'input' => $input,
        'header' => $header,
        'column' => $body,
    });
 
    $self->redirect( 'certificate!result!id!'.$queryid  );
    
    return $self;
 
}

=head2 action_privkey

Retrieve the key passphrase and - if matches - send the key as pkcs12
binary to the client.

=cut
sub action_privkey {

    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');
    my $passphrase = $self->param('passphrase');
    my $format = $self->param('format');

    my $format_mime = {
        'PKCS12' => [ 'application/x-pkcs12', 'p12' ],
        'PKCS8_PEM' => [ 'application/pkcs8', 'key' ],
        'PKCS8_DER' => [ 'application/pkcs8', 'p8' ],
        'OPENSSL_PRIVKEY' => [ 'application/x-pem-file', 'pem' ],
        'JAVA_KEYSTORE' => [ 'application/x-java-keystore', 'jks' ]
    };

    if (!$format_mime->{$format}) {
        $self->logger()->error( "Invalid key format requested ($format)" );
        $self->set_status('Invalid key format requested','error');
        return;
    }

    $self->logger()->debug( "Request privkey for $cert_identifier" );

    my $privkey  = $self->send_command ( "get_private_key_for_cert", { 
        IDENTIFIER => $cert_identifier, 
        FORMAT => $format, 
        PASSWORD => $passphrase, 
    });

    if (ref $privkey ne 'HASH' || !defined $privkey->{PRIVATE_KEY} )  {
        $self->logger()->error('Unable to get private key');
        $self->set_status('Unable to get key - wrong password?','error');
        return;
    }

    $self->logger()->debug( "Got private key " );
    my $cert_info  = $self->send_command ( "get_cert", {'IDENTIFIER' => $cert_identifier, 'FORMAT' => 'HASH' });
    my $filename = $cert_info->{BODY}->{SUBJECT_HASH}->{CN}->[0] || $cert_info->{BODY}->{IDENTIFIER};

    $self->logger()->trace( "Cert Info:  " . Dumper $cert_info );

    my $page = $self->__persist_response({
        'mime' => $format_mime->{$format}->[0],
        'attachment' => "$filename." . $format_mime->{$format}->[1],
        'data' => $privkey->{PRIVATE_KEY}
    }, '+3m');

    # We need to send the redirect to a non-ember url to load outside ember
    my $link = $self->_client()->_config()->{'scripturl'}.'?page='.$page;

    $self->_page({
        label => 'Download private key for certificate.',
        description => ''
    });

    $self->add_section({
        type => 'text',
        content => {
           title => '',
           description => 'Password accepted - <a href="'.$link.'" target="_blank">click here to download your key</a>.<br>
           Do not bookmark this link, it is temporary and will expire!'
    }});

    return $self;

}

=head2 __render_result_list

Helper to render the output result list from a sql query result.
 

=cut
sub __render_result_list {

    my $self = shift;
    my $search_result = shift;
    my $colums = shift;
    
    my @result;
    foreach my $item (@{$search_result}) {

        $item->{STATUS} = 'EXPIRED' if ($item->{STATUS} eq 'ISSUED' && $item->{NOTAFTER} < time());
            
        my @line;
        foreach my $col (@{$colums}) {
            if ($col->{field} eq 'STATUS') {
                push @line, { label => 'I18N_OPENXPKI_UI_CERT_STATUS_'.$item->{STATUS} , value => $item->{STATUS} };        
            } elsif ($col->{field} eq 'STATUSCLASS') {
                push @line, lc($item->{STATUS});
            } else {
                push @line, $item->{  $col->{field} };
            }
        }
        push @result, \@line;

    }

    return @result;

}


=head2 __render_list_spec

Create array to pass to UI from specification in config file

=cut 

sub __render_list_spec {

    my $self = shift;
    my $cols = shift;
    
    my @header;
    my @column;
    
    for (my $ii = 0; $ii < scalar @{$cols}; $ii++) {
        
        # we must create a copy as we change the hash in the session info otherwise
        my %col = %{$cols->[$ii]};
        my $head = { sTitle => $col{label} };
        if ($col{sortkey}) {
            $head->{sortkey} = $col{sortkey};
        }
        if ($col{format}) {
            $head->{format} = $col{format};
        }
        push @header, $head; 

        if ($col{template}) {

        } elsif ($col{field} =~ m{\A (csr|attribute)\.(\S+) }xi) {
            # we use this later to avoid the pattern match
            $col{source} = $1;
            $col{field} = $2;

        } else {
            $col{source} = 'certificate';
            $col{field} = uc($col{field})

        }
        push @column, \%col;
    }

    push @header, { sTitle => 'serial', bVisible => 0 };
    push @header, { sTitle => "_className"};

    push @column, { source => 'certificate', field => 'IDENTIFIER' };
    push @column, { source => 'certificate', field => 'STATUSCLASS' };
    
    return ( \@header, \@column );
}
1;
 