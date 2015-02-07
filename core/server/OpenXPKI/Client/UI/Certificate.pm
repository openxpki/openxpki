# OpenXPKI::Client::UI::Certificate
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Certificate;

use Moose;
use Data::Dumper;
use OpenXPKI::DN;
use Digest::SHA qw(sha1_base64);
use OpenXPKI::i18n qw( i18nGettext );


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

    my @profile_list = map { $_ = {'value' => $_, 'label' => i18nGettext($profile->{$_}->{label})} } @profile_names ;

    my @states = (
        { label => i18nGettext('I18N_OPENXPKI_UI_CERT_STATUS_ISSUED'), value => 'ISSUED'},
        { label => i18nGettext('I18N_OPENXPKI_UI_CERT_STATUS_VALID'), value => 'VALID'},
        { label => i18nGettext('I18N_OPENXPKI_UI_CERT_STATUS_EXPIRED'), value => 'EXPIRED'},
        { label => i18nGettext('I18N_OPENXPKI_UI_CERT_STATUS_REVOKED'), value => 'REVOKED'},
        { label => i18nGettext('I18N_OPENXPKI_UI_CERT_STATUS_CRL_PENDING'), value => 'CRL_ISSUANCE_PENDING'},
    );
    
    my $preset;
    if ($args->{preset}) {
        $preset = $args->{preset};    
    } elsif (my $queryid = $self->param('query')) {
        my $result = $self->_client->session()->param('query_cert_'.$queryid);
        $preset = $result->{input};
    }

    $self->add_section({
        type => 'form',
        action => 'certificate!search',
        content => {
           title => '',
           submit_label => 'search now',
           fields => [
                { name => 'subject', label => 'Subject', type => 'text', is_optional => 1, value => $preset->{subject} },
                { name => 'san', label => 'SAN', type => 'text', is_optional => 1, value => $preset->{san} },
                { name => 'status', label => 'status', type => 'select', is_optional => 1, prompt => 'all', options => \@states, , value => $preset->{status} },
                { name => 'profile', label => 'Profile', type => 'select', is_optional => 1, prompt => 'all', options => \@profile_list, value => $preset->{profile} },
                { name => 'meta', label => 'Metadata', 'keys' => [{ value => "meta_requestor", label=> "Requestor" },{ value => "meta_email", label => "eMail" }], type => 'text', is_optional => 1, 'clonable' => 1 },
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
    my $limit = sprintf('%01d', $self->param('limit'));
    my $startat = sprintf('%01d', $self->param('startat')); 
    
    # Safety rule
    if (!$limit) { $limit = 50; }
    elsif ($limit > 500) {  $limit = 500; }

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
        label => 'Certificate Search - Results',
        shortlabel => 'Results',
        description => 'Results of your search:',
    });

    my $i = 1;
    my @result;
    foreach my $item (@{$search_result}) {
        $item->{STATUS} = 'EXPIRED' if ($item->{STATUS} eq 'ISSUED' && $item->{NOTAFTER} < time());

        push @result, [
            $item->{CERTIFICATE_SERIAL},
            $self->_escape($item->{SUBJECT}),
            { label => i18nGettext('I18N_OPENXPKI_UI_CERT_STATUS_'.$item->{STATUS}) , value => $item->{STATUS} },
            $item->{NOTBEFORE},
            $item->{NOTAFTER},
            $self->_escape($item->{ISSUER_DN}),
            $item->{IDENTIFIER},
            lc($item->{STATUS}),
            $item->{IDENTIFIER},
        ]
    }

    $self->logger()->trace( "dumper result: " . Dumper @result);

    $self->add_section({
        type => 'grid',
        className => 'certificate',
        processing_type => 'all',
        content => {
            header => 'Grid-Headline',
            actions => [{
                path => 'certificate!detail!identifier!{identifier}',
                label => 'Download',
                icon => 'download',
                target => 'modal'
            }],
            'noop' => [{
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
            pager => { startat => $startat, limit => $limit, count => $result->{count} },
            buttons => [
                { label => 'reload search form', page => 'certificate!search!query!' .$queryid },
                { label => 'new search', page => 'certificate!search'},
            ]
        }
    });

    return $self;

}


sub init_detail {


    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');

    my $cert = $self->send_command( 'get_cert', {  IDENTIFIER => $cert_identifier });
    $self->logger()->debug("result: " . Dumper $cert);

    $self->_page({
        label => 'Certificate Information',
        shortlabel => $cert->{BODY}->{SUBJECT_HASH}->{CN}->[0],
    });


    if ($cert->{STATUS} eq 'ISSUED' && $cert->{BODY}->{NOTAFTER} < time()) {
        $cert->{STATUS} = 'EXPIRED';
    }

    # check if this is a entity certificate from the current realm
    my $is_local_entity = 0;
    if ($cert->{CSR_SERIAL} && $cert->{PKI_REALM} eq $self->_client()->session()->param('pki_realm')) {
        $self->logger()->debug("cert is local entity");
        $is_local_entity = 1;
    }

    my @fields = (
        { label => 'Subject', value => $cert->{BODY}->{SUBJECT} },
        { label => 'Serial', value => $cert->{BODY}->{SERIAL_HEX} },
        { label => 'Identifier', value => $cert_identifier },
        { label => 'not before', value => $cert->{BODY}->{NOTBEFORE}, format => 'timestamp'  },
        { label => 'not after', value => $cert->{BODY}->{NOTAFTER}, format => 'timestamp' },
        { label => 'Status', value => { label => i18nGettext('I18N_OPENXPKI_UI_CERT_STATUS_'.$cert->{STATUS}) , value => $cert->{STATUS} }, format => 'certstatus' },
        { label => 'Issuer',  format=>'link', value => { label => $cert->{BODY}->{ISSUER}, page => 'certificate!chain!identifier!'. $cert_identifier } },
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
        $privkey = '<li><a href="#certificate!privkey!identifier!'.$cert_identifier.'">'.i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_PRIVATE_KEY').'</a></li>';
    }

    push @fields, { label => 'Download', value => '<ul class="list-unstyled">'.
        sprintf ($pattern, 'pem', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_PEM')).
        # core bug see #185 sprintf ($pattern, 'txt', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_TXT')).
        sprintf ($pattern, 'der', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_DER')).
        sprintf ($pattern, 'pkcs7', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_PKCS7')).
        sprintf ($pattern, 'pkcs7!root!true', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_PKCS7_WITH_ROOT')).
        sprintf ($pattern, 'bundle', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_BUNDLE')).
        $privkey.
        sprintf ($pattern, 'install', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_INSTALL')).
        '</ul>'
    };


    my @buttons;
    push @buttons, {
        action => $self->__register_wf_token_initial('I18N_OPENXPKI_WF_TYPE_CHANGE_METADATA', { cert_identifier => $cert_identifier }),
        label  => 'metadata',
    } if ($is_local_entity);

    push @buttons, {
        #action => $self->__register_wf_token_initial('I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST', { cert_identifier => $cert_identifier }),
        page => 'workflow!index!wf_type!I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST!cert_identifier!'.$cert_identifier,
        label  => 'revoke'
    } if ($is_local_entity && $cert->{STATUS} eq 'ISSUED');

    push @buttons, {
        action => $self->__register_wf_token_initial('I18N_OPENXPKI_WF_TYPE_CERTIFICATE_RENEWAL_REQUEST', { org_cert_identifier => $cert_identifier }),
        label  => 'renew'
    } if ($is_local_entity && ($cert->{STATUS} eq 'ISSUED' || $cert->{STATUS} eq 'EXPIRED'));

    $self->add_section({
        type => 'keyvalue',
        content => {
            label => '',
            description => '',
            data => \@fields,
            #buttons => \@buttons, # We need to fix this first
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
        label => 'Certificate Chain',
        shortlabel => 'Certificate Chain',
    });

    # Download links
    my $base =  $self->_client()->_config()->{'scripturl'} . "?page=certificate!download!identifier!%s!format!%s";
    my $pattern = '<li><a href="'.$base.'" target="_blank">%s</a></li>';

    foreach my $cert (@{$chain->{CERTIFICATES}}) {

        my $dl = '<ul class="list-inline">'.
            sprintf ($pattern, $cert->{IDENTIFIER}, 'pem', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_SHORT_PEM')).
            sprintf ($pattern, $cert->{IDENTIFIER}, 'der', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_SHORT_DER')).
            sprintf ($pattern, $cert->{IDENTIFIER}, 'install', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_SHORT_INSTALL')).
            '</ul>';

        $self->add_section({
            type => 'keyvalue',
            content => {
                label => '',
                description => '',
                data => [
                    { label => i18nGettext('I18N_OPENXPKI_UI_CERTIFICATE_SUBJECT'), format => 'link', 'value' => {
                       label => $cert->{SUBJECT}, page => 'certificate!detail!identifier!'.$cert->{IDENTIFIER} } },
                    { label => i18nGettext('I18N_OPENXPKI_UI_CERTIFICATE_NOTBEFORE'), value => $cert->{NOTBEFORE}, format => 'timestamp' },
                    { label => i18nGettext('I18N_OPENXPKI_UI_CERTIFICATE_NOTAFTER'), value => $cert->{NOTAFTER}, format => 'timestamp' },
                    { label => i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_LABEL'), value => $dl },
                ],
            }},
        );
    }

    return $self;

}

sub init_workflows {


    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');


    my $workflows = $self->send_command( 'get_workflow_ids_for_cert', {  IDENTIFIER => $cert_identifier });

    $self->logger()->debug("result: " . Dumper $workflows);

    $self->_page({
        label => 'Workflows related to Certificate',
    });

    my @result;
    foreach my $line (@{$workflows}) {
        push @result, [
            $line->{'WORKFLOW.WORKFLOW_SERIAL'},
            $line->{'WORKFLOW.WORKFLOW_TYPE'},
        ];
    }

    $self->add_section({
        type => 'grid',
        className => 'workflow',
        processing_type => 'all',
        content => {
            header => 'Grid-Headline',
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
                #{ sTitle => "state"},
                #{ sTitle => "procstate"},
                #{ sTitle => "wake up"},
            ],
            data => \@result
        }
    });
    return $self;


}


sub init_privkey{

    my $self = shift;
    my $cert_identifier = $self->param('identifier');

    $self->_page({
        label => 'Download private key for certificate.',
        description => 'Please enter the key passphrase you set during certificate request.'
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

# TODO - either merge the display part with info or make sub to build buttons
sub init_download {

    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');
    my $format = $self->param('format');

    # No format, draw a list
    if (!$format) {

        my $pattern = '<li><a href="'.$self->_client()->_config()->{'scripturl'}.'?page=certificate!download!identifier!'.$cert_identifier.'!format!%s" target="_blank">%s</a></li>';


        my $privkey = '';
        # check for private key
        # TODO - add ACL, only owner should be allowed to dl key
        if ($self->send_command ( "private_key_exists_for_cert", { IDENTIFIER => $cert_identifier })) {
            $privkey = '<li><a href="#/openxpki/certificate!privkey!identifier!'.$cert_identifier.'">'.i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_PRIVATE_KEY').'</a></li>';
        }

        $self->add_section({
            type => 'text',
            content => {
                label => '',
                description => '<ul>'.
                sprintf ($pattern, 'pem', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_PEM')).
                #sprintf ($pattern, 'txt', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_TXT')). # core bug see #185
                sprintf ($pattern, 'der', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_DER')).
                sprintf ($pattern, 'pkcs7', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_PKCS7')).
                sprintf ($pattern, 'pkcs7!root!1', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_PKCS7_WITH_ROOT')).
                sprintf ($pattern, 'bundle', i18nGettext('I18N_OPENXPKI_UI_DOWNLOAD_BUNDLE')).
                $privkey.
                '</ul>',
        }});

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


=head2 action_autocomplete

Handle searches via autocomplete

=cut

sub action_autocomplete {

    my $self = shift;
    my $args = shift;

    my $term = $self->param('query') || '';

    $self->logger()->debug( "autocomplete term: " . Dumper $term);

    my $query = {
        SUBJECT => "%$term%",
        VALID_AT => time(),
        STATUS => 'ISSUED'
    };

    my $search_result = $self->send_command( 'search_cert', $query );
    $self->logger()->trace( "search result: " . Dumper $search_result);

    my @result;
    foreach my $item (@{$search_result}) {
        push @result, {
            value => $item->{IDENTIFIER},
            label => $self->_escape($item->{SUBJECT}),
            notbefore => $item->{NOTBEFORE},
            notafter => $item->{NOTAFTER}
        };
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
    foreach my $key (qw(subject issuer_dn profile)) {
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

    my @attr;
    if (my $val = $self->param('san')) {
        $input->{'san'} = $val;
        push @attr, ['subject_alt_name', $val ];
    }

    $self->logger()->debug("query : " . Dumper $self->cgi()->param());

    # the extended search attribtues are clonables and therefore
    # are suffixed with array brackets
    foreach my $key (qw(meta_requestor meta_email)) {
        my @val = $self->param($key.'[]');
        if (scalar @val > 0) {                      
            while (my $val = shift @val) {
                push @attr, [ $key , $val ];
            }            
        }
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
        'count' => $result_count,
        'query' => $query,
        'input' => $input 
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

    $self->logger()->debug( "Request privkey for $cert_identifier, Passphrase " . $passphrase);

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
    #$self->redirect( $link );

    $self->_page({
        label => 'Download private key for certificate.',
        description => ''
    });

    $self->add_section({
        type => 'text',
        content => {
           title => '',
           description => 'Password accepted - <a href="'.$link.'">click here to download your key</a>.<br>
           <b>The link expires after 60 seconds.</b>'
    }});

    return $self;

}

1;
