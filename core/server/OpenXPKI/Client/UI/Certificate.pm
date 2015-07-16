# OpenXPKI::Client::UI::Certificate
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Certificate;

use Moose;
use Data::Dumper;
use OpenXPKI::DN;
use Digest::SHA qw(sha1_base64);

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
        description => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_DESC',  
    });

    my $profile = $self->send_command( 'get_cert_profiles' );

    # TODO Sorting / I18
    my @profile_names = keys %{$profile};
    @profile_names = sort @profile_names;

    my @profile_list = map { $_ = {'value' => $_, 'label' => $profile->{$_}->{label}} } @profile_names ;

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

    my $attributes = $self->_client->session()->param('certsearch')->{default};
    if ($attributes) {
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
            'clonable' => 1
        };      
    }


    $self->add_section({
        type => 'form',
        action => 'certificate!search',
        content => {
           title => '',
           submit_label => 'search now',
           fields => \@fields
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

    $self->logger()->debug( "persisted query: " . Dumper $result);

    my $search_result = $self->send_command( 'search_cert', $query );
    
    $self->logger()->trace( "search result: " . Dumper $search_result);

    $self->_page({
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_RESULT_LABEL',       
        description => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_RESULT_DESC',
    });

    my $pager = $self->__render_pager( $result, { limit => $limit, startat => $startat } );

    my @result = $self->__render_result_list( $search_result );
    
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
            columns => [
                { sTitle => "Serial", sortkey => 'CERTIFICATE.CERTIFICATE_SERIAL' },
                { sTitle => "Subject", sortkey => 'CERTIFICATE.SUBJECT' },
                { sTitle => "Status", format => 'certstatus', sortkey => 'CERTIFICATE.STATUS' },
                { sTitle => "Notbefore", format => 'timestamp', sortkey => 'CERTIFICATE.NOTBEFORE' },
                { sTitle => "Notafter", format => 'timestamp', sortkey => 'CERTIFICATE.NOTAFTER' },
                { sTitle => "Issuer", sortkey => 'CERTIFICATE.ISSUER_DN'},
                { sTitle => "Identifier", sortkey => 'CERTIFICATE.IDENTIFIER'},
                { sTitle => "_className"},
                { sTitle => "identifier", bVisible => 0 },
            ],
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            pager => $pager,
            buttons => [
                { label => 'reload search form', page => 'certificate!search!query!' .$queryid },
                { label => 'new search', page => 'certificate!search'},
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
    } else {        
        $query->{ORDER} = 'NOTBEFORE';
        if (!defined $self->param('reverse')) {
            $query->{REVERSE} = 1;
        }
    }
    
    if (defined  $self->param('reverse')) {
        $query->{REVERSE} = $self->param('reverse');
    }

    $self->logger()->debug( "persisted query: " . Dumper $result);
    $self->logger()->debug( "executed query: " . Dumper $query);

    my $search_result = $self->send_command( 'search_cert', $query );
    
    $self->logger()->trace( "search result: " . Dumper $search_result);
     
    my @result = $self->__render_result_list( $search_result ); 
        
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
        }]
    };

    $self->logger()->debug( "search query: " . Dumper $query);

    my $search_result = $self->send_command( 'search_cert', { %$query, ( LIMIT => $limit, START => $startat ) } );
    
    my $result_count = scalar @{$search_result};
    my $pager;
    if ($result_count == $limit) {
        $result_count = $self->send_command( 'search_cert_count', $query );

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
    
    my @result = $self->__render_result_list( $search_result );
     
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
            columns => [
                { sTitle => "Serial"},
                { sTitle => "Subject" },
                { sTitle => "Status", format => 'certstatus' },
                { sTitle => "Notbefore", format => 'timestamp' },
                { sTitle => "Notafter", format => 'timestamp' },
                { sTitle => "Issuer"},
                { sTitle => "Identifier"},
                { sTitle => "_className"},
                { sTitle => "identifier", bVisible => 0 },
            ],
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

    my $cert = $self->send_command( 'get_cert', {  IDENTIFIER => $cert_identifier, FORMAT => 'DBINFO' });
    $self->logger()->debug("result: " . Dumper $cert);
    
    my %dn = OpenXPKI::DN->new( $cert->{SUBJECT} )->get_hashed_content();
    
    $self->_page({
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_DETAIL_LABEL',
        shortlabel => $dn{CN}[0]
    });

    # check if this is a entity certificate from the current realm
    my $is_local_entity = 0;
    if ($cert->{CSR_SERIAL} && $cert->{PKI_REALM} eq $self->_session->param('pki_realm')) {
        $self->logger()->debug("cert is local entity");
        $is_local_entity = 1;
    }

    my @fields = (
        { label => 'Subject', value => $cert->{SUBJECT} },
        { label => 'Serial', value => $cert->{CERTIFICATE_SERIAL_HEX} },
        { label => 'Identifier', value => $cert_identifier },
        { label => 'not before', value => $cert->{NOTBEFORE}, format => 'timestamp'  },
        { label => 'not after', value => $cert->{NOTAFTER}, format => 'timestamp' },
        { label => 'Status', value => { label => 'I18N_OPENXPKI_UI_CERT_STATUS_'.$cert->{STATUS} , value => $cert->{STATUS} }, format => 'certstatus' },
        { label => 'Issuer',  format=>'link', value => { label => $cert->{ISSUER_DN}, page => 'certificate!chain!identifier!'. $cert_identifier } },
    );

    # for i18n parser I18N_OPENXPKI_CERT_ISSUED CRL_ISSUANCE_PENDING I18N_OPENXPKI_CERT_REVOKED I18N_OPENXPKI_CERT_EXPIRED

    # was in info, bullet list for downloads
    my $base =  $self->_client()->_config()->{'scripturl'} . "?page=certificate!download!identifier!$cert_identifier!format!";
    my $pattern = '<li><a href="'.$base.'%s" target="_blank">%s</a></li>';

    my $privkey = '';
    # check for private key
    # TODO - add ACL, only owner should be allowed to dl key
    if ($is_local_entity &&
        $self->send_command ( "private_key_exists_for_cert", { IDENTIFIER => $cert_identifier })) {
        $privkey = '<li><a href="#/openxpki/certificate!privkey!identifier!'.$cert_identifier.'">I18N_OPENXPKI_UI_DOWNLOAD_PRIVATE_KEY</a></li>';
    }

    push @fields, { label => 'I18N_OPENXPKI_UI_DOWNLOAD_LABEL', value => '<ul class="list-unstyled">'.
        sprintf ($pattern, 'pem', 'I18N_OPENXPKI_UI_DOWNLOAD_PEM').
        # core bug see #185 sprintf ($pattern, 'txt', 'I18N_OPENXPKI_UI_DOWNLOAD_TXT').
        sprintf ($pattern, 'der', 'I18N_OPENXPKI_UI_DOWNLOAD_DER').
        sprintf ($pattern, 'pkcs7', 'I18N_OPENXPKI_UI_DOWNLOAD_PKCS7').
        sprintf ($pattern, 'pkcs7!root!true', 'I18N_OPENXPKI_UI_DOWNLOAD_PKCS7_WITH_ROOT').
        sprintf ($pattern, 'bundle', 'I18N_OPENXPKI_UI_DOWNLOAD_BUNDLE').
        $privkey.
        sprintf ($pattern, 'install', 'I18N_OPENXPKI_UI_DOWNLOAD_INSTALL').
        '</ul>'
    };

    # TODO - add some magic to the API to determine if those actions are possible for the current user, etc.
    $pattern = '<li><a href="#/openxpki/redirect!workflow!index!wf_type!%s!cert_identifier!'.$cert_identifier.'">%s</a></li>';
    
    if ($is_local_entity) {   
        my @actions;
        if ($is_local_entity && ($cert->{STATUS} eq 'ISSUED' || $cert->{STATUS} eq 'EXPIRED')) {        
            push @actions, sprintf ($pattern, 'certificate_renewal_request', 'I18N_OPENXPKI_UI_CERT_ACTION_RENEW');
        }
        if ($cert->{STATUS} eq 'ISSUED') { 
            push @actions, sprintf ($pattern, 'certificate_revocation_request_v2', 'I18N_OPENXPKI_UI_CERT_ACTION_REVOKE');
        }
        push @actions, sprintf ($pattern, 'change_metadata', 'I18N_OPENXPKI_UI_CERT_ACTION_UPDATE_METADATA');
        
        push @fields, { label => 'I18N_OPENXPKI_UI_CERT_ACTION_LABEL', value => '<ul class="list-unstyled">'.join("", @actions).'</ul>' };
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
                    { label => 'I18N_OPENXPKI_UI_DOWNLOAD_LABEL', value => $dl },
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
        ];
    }
    
    $self->add_section({
        type => 'grid',
        className => 'workflow',
        content => {
            label => 'I18N_OPENXPKI_UI_CERTIFICATE_RELATED_WORKFLOW_LABEL',
            actions => [{
                path => 'workflow!load!wf_id!{serial}',
                label => 'Open Workflow',
                icon => 'view',
                target => 'tab',
            }],
            columns => [
                { sTitle => "serial" },
                #{ sTitle => "updated" },
                { sTitle => "type"},
                { sTitle => "state"},
                #{ sTitle => "procstate"},
                #{ sTitle => "wake up"},
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
                    #{ value => 'JAVA_KEYSTORE', label => 'Java Keystore' }
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
            $query->{uc($key)} = $val;
            $input->{$key} = $val;
        }
    }

    if (my $status = $self->param('status')) {
        $input->{'status'} = $status;
        if ($status eq 'EXPIRED') {
            $status = 'ISSUED';
            $query->{NOTAFTER} = time();
        } elsif ($status eq 'VALID') {
            $status = 'ISSUED';
            $query->{VALID_AT} = time();
        }
        $query->{STATUS} = $status;        
    }

    $self->logger()->debug("query : " . Dumper $self->cgi()->param());

    # Read the query pattern for extra attributes from the session 
    my $attributes = $self->_client->session()->param('certsearch')->{default};
    my @attr = @{$self->__build_attribute_subquery( $attributes )};        

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
        $self->set_status('Your query did not return any matches.','error');
        return $self->init_search({ preset => $input });
    }
    
    my $queryid = $self->__generate_uid();
    $self->_client->session()->param('query_cert_'.$queryid, {
        'id' => $queryid,
        'type' => 'certificate',
        'count' => $result_count,
        'query' => $query,
        'input' => $input,
        'column' =>[] 
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
        #'JAVA_KEYSTORE' => [ 'application/x-java-keystore', 'jks' ]
    };

    if (!$format_mime->{$format}) {
        $self->logger()->error( "Invalid key format requested ($format)" );
        $self->set_status('Invalid key format requested','error');
        return;
    }

    $self->logger()->debug( "Request privkey for $cert_identifier" );

    my $privkey  = $self->send_command ( "get_private_key_for_cert", { IDENTIFIER => $cert_identifier, FORMAT => $format, 'PASSWORD' => $passphrase });

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
           <b>The link expires after 60 seconds.</b>'
    }});

    return $self;

}

=head2 __render_result_list

Helper to render the output result list from a sql query result.
 

=cut
sub __render_result_list {

    my $self = shift;
    my $search_result = shift;
    #my $colums = shift;
    
    my @result;
    foreach my $item (@{$search_result}) {
        $item->{STATUS} = 'EXPIRED' if ($item->{STATUS} eq 'ISSUED' && $item->{NOTAFTER} < time());

        push @result, [
            $item->{CERTIFICATE_SERIAL},
            $self->_escape($item->{SUBJECT}),
            { label => 'I18N_OPENXPKI_UI_CERT_STATUS_'.$item->{STATUS} , value => $item->{STATUS} },
            $item->{NOTBEFORE},
            $item->{NOTAFTER},
            $self->_escape($item->{ISSUER_DN}),
            $item->{IDENTIFIER},
            lc($item->{STATUS}),
            $item->{IDENTIFIER},
        ]
    }

    return @result;    
}
1;
 