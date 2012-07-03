# OpenXPKI::Server::Workflow::Activity::SmartCard::CreateServerCSR
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::CreateServerCSR;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;
use Template;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my @cert_profiles = split(/,/, $self->param('cert_profiles'));
    my @cert_roles    = split(/,/, $self->param('cert_roles'));

    # allows to specify explicit usage of a configured profile/role index
    # in action definition
    my $forced_index = $self->param('force_profile_index');

    my $cert_issuance_data_ser = $context->param('cert_issuance_data');
    my @cert_issuance_data;
    if (defined $cert_issuance_data_ser) {
        ##! 4: 'cert_issuance_data_ser defined'
        @cert_issuance_data = @{$serializer->deserialize($cert_issuance_data_ser)};
    }
    else { # first time, write the number of certificates to the
           # workflow context
        $context->param('nr_of_certs' => scalar @cert_profiles);

	# only retrieve this data if chosen_loginid is set
	if (defined $context->param('chosen_loginid')) {
	    # Lookup UPN from AD
	    my $ad_server;
	    my $ad_port = 389;
	    my $ad_userdn     = $self->param('ad_userdn');
	    my $ad_pass       = $self->param('ad_pass');
	    my $ad_basedn;
	    my $ad_timelimit  = $self->param('ad_timelimit');

	    my ($domain, $userid)
		= ($context->param('chosen_loginid') =~ m{ \A (.+)\\(.+) }xms);
	    if ($domain =~ m{\A (?:deuba|zzdbe) \z}xmsi) {
		# test: "yydbe.yyads.db.com";
		# prod: "dbe.ads.db.com";
		$ad_server = $self->param('ad_deuba_server');
		# test: "dc=yydbe,dc=yyads,dc=db,dc=com";
		# prod: "dc=dbe,dc=ads,dc=db,dc=com";
		$ad_basedn = $self->param('ad_deuba_basedn');
	    }
	    elsif ($domain =~ m{\A (?:dbg|zzdbg) \z}xmsi) {
		# prod: "dbg.ads.db.com";
		$ad_server = $self->param('ad_dbg_server');
		# prod: "dc=dbg,dc=ads,dc=db,dc=com";
		$ad_basedn = $self->param('ad_dbg_basedn');
	    }
	    elsif ($domain =~ m{\A itcbod \z}xmsi) {
		# prod: "itcbod.ads.db.com";
		$ad_server = $self->param('ad_itcbod_server');
		# prod: "dc=itcbod,dc=ads,dc=db,dc=com";
		$ad_basedn = $self->param('ad_itcbod_basedn');
	    }
	    elsif ($domain =~ m{\A dblux \z}xmsi) {
		# prod: ?
		$ad_server = $self->param('ad_dblux_server');
		# prod: ?
		$ad_basedn = $self->param('ad_dblux_basedn');
		# DBLUX has a different user name and password
		$ad_userdn = $self->param('ad_dblux_userdn');
		$ad_pass   = $self->param('ad_dblux_pass');
	    }
	    elsif ($domain =~ m{\A dbch \z}xmsi) {
		$ad_server = $self->param('ad_dbch_server');
		$ad_basedn = $self->param('ad_dbch_basedn');
		$ad_userdn = $self->param('ad_dbch_userdn');
		$ad_pass   = $self->param('ad_dbch_pass');
	    }
	    else {
		OpenXPKI::Exception->throw(
		    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_CREATESERVERCSR_UNKNOWN_DOMAIN_USED',
		    params  => {
			'DOMAIN'  => $domain,
			'USER'    => $userid,
			'LOGINID' => $context->param('chosen_loginid'),
		    },
		    );
	    }
	    
	    if ($ad_server =~ m{ : }xms) { 
		($ad_server, $ad_port) = ($ad_server =~ m{ (.+) : (\d+) \z }xms);
	    }
	    
	    $context->param('ad_server' => $ad_server);
	    $context->param('ad_port'   => $ad_port);
	    $context->param('ad_basedn' => $ad_basedn);
	    
	    ##! 2: 'connecting to ldap server ' . $ad_server. ':' . $ad_port
	    my $ldap = Net::LDAP->new(
		$ad_server,
		port    => $ad_port,
		onerror => undef,
		);
	    
	    ##! 2: 'ldap object created'
	    # TODO: maybe use TLS ($ldap->start_tls())?
	    
	    if (! defined $ldap) {
		OpenXPKI::Exception->throw(
		    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_CREATESERVERCSR_LDAP_CONNECTION_FAILED',
		    params => {
			'LDAP_SERVER' => $ad_server,
			'LDAP_PORT'   => $ad_port,
		    },
		    );
	    }
	    
	    my $mesg = $ldap->bind(
		$ad_userdn,
		password => $ad_pass,
		);
	    if ($mesg->is_error()) {
		OpenXPKI::Exception->throw(
		    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_CREATESERVERCSR_LDAP_BIND_FAILED',
		    params  => {
			ERROR      => $mesg->error(),
			ERROR_DESC => $mesg->error_desc(),
		    },
		    );
	    }
	    ##! 2: 'ldap->bind() done'
	    
	    my $filter = "(&(sAMAccountName=$userid) (objectCategory=person))";
	    
	    $mesg = $ldap->search(base      => $ad_basedn,
				  scope     => 'sub',
				  filter    => $filter,
				  attrs     => [ 'userPrincipalName' ],
				  timelimit => $ad_timelimit,
		);
	    if ($mesg->is_error()) {
		OpenXPKI::Exception->throw(
		    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_CREATESERVERCSR_LDAP_SEARCH_FAILED',
		    params  => {
			ERROR      => $mesg->error(),
			ERROR_DESC => $mesg->error_desc(),
		    },
		    );
	    }
	    ##! 2: 'ldap->search() done'
	    ##! 16: 'mesg->count: ' . $mesg->count
	    
	    if ($mesg->count == 0) {
		OpenXPKI::Exception->throw(
		    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_CREATESERVERCSR_LDAP_ENTRY_NOT_FOUND',
		    params  => {
			'BASEDN' => $ad_basedn,
			'FILTER' => $filter,
		    },
		    );
	    }
	    elsif ($mesg->count > 1) {
		OpenXPKI::Exception->throw(
		    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_CREATESERVERCSR_MORE_THAN_ONE_LDAP_ENTRY_FOUND',
		    params  => {
			'BASEDN' => $ad_basedn,
			'FILTER' => $filter,
		    },
		    );
	    }
	    
	    foreach my $entry ($mesg->entries) {
		##! 32: 'foreach entry'
		##! 32: 'dn: ' . $entry->dn()
		$context->param('ad_entrydn' => $entry->dn());
		foreach my $attrib ($entry->attributes) {
		    ##! 32: 'foreach attrib: ' . $attrib
		    my @values = $entry->get_value($attrib);
		    ##! 32: 'attrib values: ' . Dumper \@values
		    if (scalar @values == 1) { # scalar
			$context->param(
			    'ldap_' . $attrib => $values[0],
			    );
		    }
		    else { # non-scalar!
			OpenXPKI::Exception->throw(
			    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_CREATESERVERCSR_UPN_MULTIVALUED',
			    );
		    }
		}
	    }
	}
    }

    # prepare LDAP variable hashref for Template Toolkit
    my $ldap_vars;
    foreach my $param (keys %{ $context->param() }) {
        if ($param =~ s{ \A ldap_ }{}xms) {
            ##! 64: 'adding param ' . $param . ' to ldap_vars, value: ' . $context->param('ldap_' . $param)
            $ldap_vars->{$param} = $context->param('ldap_' . $param);
        }
    }
    # process subject using TT
    my $template = $self->param('cert_subject');
    my $tt = Template->new();
    my $cert_subject = '';
    $tt->process(\$template, $ldap_vars, \$cert_subject);
    ##! 16: 'cert_subject: ' . $cert_subject

    # process subject alternative names using TT
    $template = $self->param('cert_subject_alt_names');
    my $cert_subj_alt_names = '';
    $tt->process(\$template, $ldap_vars, \$cert_subj_alt_names);
    ##! 16: 'cert_subj_alt_names: ' . $cert_subj_alt_names

    my @sans = split(/,/, $cert_subj_alt_names);
    foreach my $entry (@sans) {
        my @tmp_array = split(/=/, $entry);
        $entry = \@tmp_array;
    }
    ##! 16: '@sans: ' . Dumper(\@sans)

    my $current_pos = scalar @cert_issuance_data;
    if (defined $forced_index) {
	$current_pos = $forced_index;

	# update number of certs to issue
        $context->param('nr_of_certs' => (scalar @cert_issuance_data) + 1);
    }
    
    my $cert_issuance_hash_ref = {
        'pkcs10'                => $context->param('pkcs10'),
        'csr_type'              => 'pkcs10',
        'cert_profile'          => $cert_profiles[$current_pos],
        'cert_role'             => $cert_roles[$current_pos],
        'cert_subject'          => $cert_subject,
        'cert_subject_alt_name' => \@sans,
    };
    ##! 16: 'cert_iss_hash_ref: ' . Dumper($cert_issuance_hash_ref)
    push @cert_issuance_data, $cert_issuance_hash_ref;
    ##! 16: 'cert_issuance_data: ' . Dumper(\@cert_issuance_data)
    $context->param(
        'cert_issuance_data' => $serializer->serialize(\@cert_issuance_data),
    );
    ##! 4: 'end'
    ##! 16: 'chosen_loginid: ' . $context->param('chosen_loginid')
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::CreateServerCSR

=head1 Description

This class takes the CSR from the client and sets up an array of
hashrefs in the context (cert_issuance_data) which contains all
information needed to persist them in the database and then fork
certificate issuance workflows.
