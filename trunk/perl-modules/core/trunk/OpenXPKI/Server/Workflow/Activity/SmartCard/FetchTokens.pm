# OpenXPKI::Server::Workflow::Activity::SmartCard::FetchTokens
# Written by Scott Hardin for the OpenXPKI project 2010
#
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::FetchTokens;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use English;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub _get_conf {
    my $self    = shift;
    my $arg_ref = shift;

    our $policy = {
        directory => {
            ldap => {
                uri     => 'ldap://localhost:389',
                bind_dn => 'cn=admin,dc=example,dc=com',
                pass    => 'changeme',
            },
            person => {
                basedn                  => 'ou=persons,dc=example,dc=com',
                userid_attribute        => 'mail',
                loginid_attribute       => 'ntloginid',
                max_smartcards_per_user => 1,
                attributes => [qw( CN givenName initials sn mail )],
            },
            smartcard => { basedn => 'ou=smartcards,dc=example,dc=com', },
        },
    };

    # 2010-11-02 Scott Hardin: TODO FIXME XXX
    # Some bad habits seem to get repeated, don't they.
    #
    # This is just a kludge to get the LDAP code up-n-running
    # without tackling the whole issue of configuration.
    do '/etc/openxpki/policy.pm'
        or die "Could not open ldap parameters file.";

    return $policy;
}

sub _get_ldap_conn {
    my $self = shift;
    my $conf = shift;
    my $ldap;

    my $ldap_conf = $conf->{directory}->{ldap};

    eval {
        if ( $ldap_conf->{uri} =~ /^ldaps:/ )
        {
            require Net::LDAPS;
            import Net::LDAPS;
            $ldap = Net::LDAPS->new( $ldap_conf->{uri}, onerror => undef, );
        }
        else {
            require Net::LDAP;
            import Net::LDAP;
            $ldap = Net::LDAP->new( $ldap_conf->{uri}, onerror => undef, );
        }
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message =>
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_NET_LDAP_EVAL_ERR',
            params => { 'EVAL_ERROR' => $EVAL_ERROR, },
            log    => {
                logger   => CTX('log'),
                priority => 'error',
                facility => 'monitor',
            },
        );
    }

    if ( !defined $ldap ) {
        OpenXPKI::Exception->throw(
            message =>
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_CONNECTION_FAILED',
            params => { 'LDAP_URI' => $ldap_conf->{uri}, },
            log    => {
                logger   => CTX('log'),
                priority => 'error',
                facility => 'monitor',
            },
        );
    }

    my $mesg = $ldap->bind( $ldap_conf->{bind_dn},
        password => $ldap_conf->{pass} );
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

    return $ldap;
}

sub execute {
    ##! 1: 'Entered FetchTokens::execute()'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();

    my $email = $context->param('token_owner');
    my $conf  = $self->_get_conf();
    my $ldap  = $self->_get_ldap_conn($conf);

    my $recs = [];

    # vars for searching for person records
    my $pers_key   = 'mail';
    my @pers_attrs = qw( cn mail tel seealso );

    # vars for scb records
    my $scb_key   = 'scbserialnumber';
    my @scb_attrs = qw( scbserialnumber scbstatus );

    #
    # Start by fetching the person record(s) from LDAP
    #

    my $mesg = $ldap->search(
        base      => $conf->{directory}->{person}->{basedn},
        scope     => 'sub',
        filter    => "($pers_key=$email)",
        attrs     => \@pers_attrs,
        timelimit => $conf->{directory}->{ldap}->{timeout},
    );
    if ( $mesg->is_error() ) {
        $self->throw(
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_SEARCH_FAILED',
            {   ERROR      => $mesg->error(),
                ERROR_DESC => $mesg->error_desc(),
            },
        );
    }

	##! 16: "search for '$pers_key=$email' returned " . $mesg->count . " record(s)"

    #
    # For each person, grab the attrs and details for each scb in seeAlso
    #

    my $i = 0;


    foreach my $p_entry ( $mesg->entries ) {
        my $p = {};
        push @{ $recs }, $p;
#        my $param_base = 'person_' . $i;

        foreach my $key (@pers_attrs) {
            if ( $key eq 'seealso' ) {
                # get value of seealso in list context
                $p->{$key} = [ $p_entry->get_value($key) ];
            } else {
                $p->{$key} = $p_entry->get_value($key);
            }
#            $context->param( $param_base . $key, $p->{$key} );
        }

        foreach my $scb_value ( @{ $p->{seealso} } ) {

        ##! 16: "token_owner=$email, scb_value=$scb_value"

        # filter scb entries and chop off base DN in same shot
        if ( $scb_value =~ s/^(scbserialnumber=[^,]*).*$/$1/ ) {

            my $token_id = $scb_value;
            $token_id =~ s/^scbserialnumber=//;

            ##! 16: "chopped scb_value=$scb_value, token_id=$token_id"

            my $mesg2 = $ldap->search(
                base      => $conf->{directory}->{smartcard}->{basedn},
                scope     => 'sub',
                filter    => "($scb_key=$token_id)",
                attrs     => \@scb_attrs,
                timelimit => $conf->{directory}->{ldap}->{timeout},
            );

     # Not sure if an error should be fatal here, but it probably doesn't hurt
            if ( $mesg2->is_error() ) {
                $self->throw(
                    'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GETLDAPDATA_LDAP_SEARCH_FAILED',
                    {   ERROR      => $mesg2->error(),
                        ERROR_DESC => $mesg2->error_desc(),
                    },
                );
            }

            my $j = 0;
            foreach my $scb_entry ( $mesg2->entries ) {
                $p->{scb} ||= [];
                my $scb = {};
                push @{ $p->{scb} }, $scb;

                foreach my $key2 (@scb_attrs) {
                    $scb->{$key2} = $scb_entry->get_value($key2);
                }
            }
        }
        }

    }

   #
   # Now that we have the data, lets massage it into something that can be
   # tucked into the workflow context.

    $context->param( '_ldap_data', $recs );


    # 
    # If just one person with just one token was found...
    # 

    if ( @{ $recs } == 1 ) {

        # If just one token was found, put it into context param 'token_id'
        if ( ref( $recs->[0]->{scb} ) eq 'ARRAY' and @{ $recs->[0]->{scb} } == 1 ) {
            $context->param( token_id => $recs->[0]->{scb}->[0]->{scbserialnumber} );
        }

        # If more than one token was found, put them into 'multi_token_ids'
        if ( ref( $recs->[0]->{scb} ) eq 'ARRAY' and @{ $recs->[0]->{scb} } > 1 ) {
            my $scbs = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
                {
                    workflow => $workflow,
                    context_key => 'multi_ids',
                }
            );
            foreach my $scb ( @{ $recs->[0]->{scb} } ) {
                $scbs->push( $scb->{scbserialnumber} );
            }
        }
    }

=begin deprecated

	my $token_id = $context->param('token_id');

	my %params;
	if ($context->param('login_id') ne '') {
	    $params{USERID} = $context->param('login_id');
	}

	my @certs = split(/;/, $context->param('certs_on_card'));

	my $wf_types = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    {
		workflow    => $workflow,
		context_key => 'workflow_types',
	    } );

	my $result = CTX('api')->sc_analyze_smartcard(
	    {
 		CERTS => \@certs,
		CERTFORMAT => 'BASE64',
		SMARTCARDID => $context->param('token_id'),
		WORKFLOW_TYPES => $wf_types->values(),
		CONFIG_ID => $self->config_id(),
		%params,
	     
	    });

	##! 16: 'smartcard analyzed: ' . Dumper $result
	

	# set cert ids in context
	my $cert_ids = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    {
		workflow    => $workflow,
		context_key => 'certids_on_card',
	    } );
	$cert_ids->push(
	    map { $_->{IDENTIFIER} } @{$result->{CERTS}}
	    );
	
	
	my $cert_types = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    {
		workflow    => $workflow,
		context_key => 'certificate_types',
	    } );

	foreach my $type (keys %{$result->{CERT_TYPE}}) {
	    $cert_types->push($type);

	    foreach my $entry (keys %{$result->{CERT_TYPE}->{$type}}) {
		# FIXME: find a better way to name the flags properly, currently
		# the resulting wf keys depend on the configuration (i. e.
		# configured certificate types)
		
		my $value = 'no';
		if ($result->{CERT_TYPE}->{$type}->{$entry}) {
		    $value = 'yes';
		}

		$context->param('flag_' . $type . '_' . $entry
				=> $value);
	    }
	}

	
	foreach my $flag (keys %{$result->{PROCESS_FLAGS}}) {
	    # propagate flags
	    my $value = 'no';
	    if ($result->{PROCESS_FLAGS}->{$flag}) {
		$value = 'yes';
	    }
	    $context->param('flag_' . $flag => $value);
	}


	# propagate LDAP settings to context
      LDAP_ENTRY:
	foreach my $entry (keys (%{$result->{SMARTCARD}->{assigned_to}})) {
	    my $value = $result->{SMARTCARD}->{assigned_to}->{$entry};
	    if (ref $value eq 'ARRAY') {
		my $queue = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
		    {
			workflow    => $workflow,
			context_key => 'ldap_' . $entry ,
		    } );
		$queue->push(@{$value});
	    } else {
		$context->param('ldap_' . $entry => 
				$result->{SMARTCARD}->{assigned_to}->{$entry});
	    }
	}

	############################################################
	# propagate wf tasks to context
	my $certs_to_install = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    {
		workflow    => $workflow,
		context_key => 'certs_to_install',
	    } );
	$certs_to_install->push(
	    @{$result->{TASKS}->{SMARTCARD}->{INSTALL}}
	    );

	my $certs_to_delete = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    {
		workflow    => $workflow,
		context_key => 'certs_to_delete',
	    } );
	$certs_to_delete->push(
	    @{$result->{TASKS}->{SMARTCARD}->{PURGE}}
	    );

	
	my $certs_to_unpublish = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    {
		workflow    => $workflow,
		context_key => 'certs_to_unpublish',
	    } );
	$certs_to_unpublish->push(
	    @{$result->{TASKS}->{DIRECTORY}->{UNPUBLISH}}
	    );


	
	$context->param('smartcard_status' =>
			$result->{SMARTCARD}->{status});
	
	$context->param('keysize' =>
			$result->{SMARTCARD}->{keysize});

	$context->param('keyalg' =>
			$result->{SMARTCARD}->{keyalg});
	
	$context->param('smartcard_default_puk' =>
			$result->{SMARTCARD}->{default_puk});
	
=end deprecated

=cut

    ##! 1: 'Leaving Initialize::execute()'
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::FetchTokens

=head1 Description

This activity searches the LDAP for smartcard entries and returns
the results.

=head2 Context parameters

The following context parameters set during initialize are read:

=over 8

=item token_id

Token ID assigned to given person. If more than one token is found, this should be the preferred entry.

=item token_status

Status of the token in I<token_id>.

=item person_N_KEY

Stores the given I<KEY> parameter for person I<N>. This is a kludge to support when
more than one person is found.

=item scb_N_KEY

Stores the given I<KEY> parameter for scb I<N>. This is a kludge to support when
more than one scb is found.

=back

=head1 Functions

=head2 execute

Executes the action.
