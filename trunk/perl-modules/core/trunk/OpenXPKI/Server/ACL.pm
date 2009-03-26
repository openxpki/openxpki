## OpenXPKI::Server::ACL.pm 
##
## Written by Michael Bell 2006
## cleaned up a bit to support multiple PKI realms
## by Alexander Klink 2007
## Copyright (C) 2006 by The OpenXPKI Project

package OpenXPKI::Server::ACL;

use strict;
use warnings;
use utf8;
use English;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use Data::Dumper;

## constructor and destructor stuff

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = shift;
    ##! 1: "start"

    return undef if (not $self->__load_config ($keys));

    ##! 1: "end"
    return $self;
}

#############################################################################
##                         load the configuration                          ##
##                            (caching support)                            ##
#############################################################################

sub __load_config
{
    my $self = shift;
    ##! 1: "start"

    my $keys   = shift;
    my $cfg_id = $keys->{CONFIG_ID};

    ## load all PKI realms

    my $realms = CTX('xml_config')->get_xpath_count(
        XPATH     => 'pki_realm',
        CONFIG_ID => $cfg_id,
    );
    for (my $i=0; $i < $realms; $i++)
    {
        $self->__load_pki_realm ({PKI_REALM => $i, CONFIG_ID => $cfg_id});
    }

    ##! 1: "leaving function successfully"
    return 1;
}

sub __load_pki_realm
{
    my $self   = shift;
    my $keys   = shift;
    my $realm  = $keys->{PKI_REALM};
    my $cfg_id = $keys->{CONFIG_ID};

    my $name = CTX('xml_config')->get_xpath (XPATH     => ['pki_realm', 'name'],
                                             COUNTER   => [$realm, 0],
                                             CONFIG_ID => $cfg_id,
    );
    $self->{PKI_REALM}->{$name}->{POS} = $realm;

    $self->__load_server      ({PKI_REALM => $name, CONFIG_ID => $cfg_id});
    $self->__load_roles       ({PKI_REALM => $name, CONFIG_ID => $cfg_id});
    $self->__load_permissions ({PKI_REALM => $name, CONFIG_ID => $cfg_id});
    $self->__load_workflow_permissions({
        PKI_REALM => $name,
        CONFIG_ID => $cfg_id,
    });

    return 1;
}

sub __load_server
{
    my $self  = shift;
    my $keys  = shift;
    ##! 1: 'start'
    my $realm  = $keys->{PKI_REALM};
    my $cfg_id = $keys->{CONFIG_ID};
    my $pkiid  = $self->{PKI_REALM}->{$realm}->{POS};

    # get the ID of the server that we are on
    # (for some reason, this ID lives in the database part of the
    #  configuration)
    my $our_server_id = CTX('xml_config')->get_xpath (
         XPATH   => ['common', 'database', 'server_id'],
         COUNTER => [0, 0, 0],
         CONFIG_ID => $cfg_id,
    );
    my $servers = CTX('xml_config')->get_xpath_count (
                      XPATH   => ['pki_realm', 'acl', 'server'],
                      COUNTER => [$pkiid, 0],
                      CONFIG_ID => $cfg_id,
                  );

    for (my $i=0; $i < $servers; $i++) {
        my $id   = CTX('xml_config')->get_xpath (
                       XPATH   => ['pki_realm', 'acl', 'server', 'id'],
                       COUNTER => [ $pkiid, 0, $i, 0],
                       CONFIG_ID => $cfg_id,
                   );
        my $name = CTX('xml_config')->get_xpath (
                       XPATH   => ['pki_realm', 'acl', 'server', 'name'],
                       COUNTER => [ $pkiid, 0, $i, 0],
                       CONFIG_ID => $cfg_id,
                   );
        if (exists $self->{SERVER}->{$realm}->{$id}) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_ACL_LOAD_SERVER_DUPLICATE_ID_FOUND",
                params  => {ID   => $id,
                            NAME => $name});
        }
        $self->{SERVER}->{$realm}->{$id} = $name;
        if ($id == $our_server_id) {
            $self->{SERVER_NAME} = $name;
        }
    }
    ##! 16: 'self->{SERVER}: ' . Dumper $self->{SERVER}
    ##! 1: 'end'
    return 1;
}

sub __load_roles
{
    my $self   = shift;
    my $keys   = shift;
    my $realm  = $keys->{PKI_REALM};
    my $cfg_id = $keys->{CONFIG_ID};
    my $pkiid  = $self->{PKI_REALM}->{$realm}->{POS};

    my $roles = CTX('xml_config')->get_xpath_count (
                      XPATH   => ['pki_realm', 'acl', 'role'],
                      COUNTER => [$pkiid, 0],
                      CONFIG_ID => $cfg_id,
                  );
    for (my $i=0; $i < $roles; $i++)
    {
        my $role = CTX('xml_config')->get_xpath (
                       XPATH   => ['pki_realm', 'acl', 'role'],
                       COUNTER => [ $pkiid, 0, $i],
                       CONFIG_ID => $cfg_id,
                   );
        $self->{PKI_REALM}->{$realm}->{ROLES}->{$role} = 1;
    }
    ## add empty role for things which have no owner or are owned by the CA
    $self->{PKI_REALM}->{$realm}->{ROLES}->{""} = 1;
    return 1;
}

sub __load_permissions
{
    my $self   = shift;
    my $keys   = shift;
    my $realm  = $keys->{PKI_REALM};
    my $cfg_id = $keys->{CONFIG_ID};
    my $pkiid  = $self->{PKI_REALM}->{$realm}->{POS};

    my $perms = CTX('xml_config')->get_xpath_count (
                      XPATH   => ['pki_realm', 'acl', 'permission'],
                      COUNTER => [$pkiid, 0],
                      CONFIG_ID => $cfg_id,
                  );
    for (my $i=0; $i < $perms; $i++)
    {
        my $server = CTX('xml_config')->get_xpath (
                       XPATH   => ['pki_realm', 'acl', 'permission', 'server'],
                       COUNTER => [ $pkiid, 0, $i],
                       CONFIG_ID => $cfg_id,
                   );
        my $activity = CTX('xml_config')->get_xpath (
                       XPATH   => ['pki_realm', 'acl', 'permission', 'activity'],
                       COUNTER => [ $pkiid, 0, $i],
                       CONFIG_ID => $cfg_id,
                   );
        my $owner = CTX('xml_config')->get_xpath (
                       XPATH   => ['pki_realm', 'acl', 'permission', 'affected_role'],
                       COUNTER => [ $pkiid, 0, $i],
                       CONFIG_ID => $cfg_id,
                   );
        my $user = CTX('xml_config')->get_xpath (
                       XPATH   => ['pki_realm', 'acl', 'permission', 'auth_role'],
                       COUNTER => [ $pkiid, 0, $i],
                       CONFIG_ID => $cfg_id,
                   );

        my @perms = ();

        ## evaluate server
        if ($server ne "*" and
            $server ne $self->{SERVER_NAME})
        {
            ## we only need the permissions for this server
            ## this reduces the propabilities of hash collisions
            next;
        }

        ## evaluate owner
        my @owners = ($owner);
           @owners = keys %{$self->{PKI_REALM}->{$realm}->{ROLES}}
               if ($owner eq "*");

        ## evaluate user
        my @users = ($user);
           @users = keys %{$self->{PKI_REALM}->{$realm}->{ROLES}}
               if ($user eq "*");

        ## an activity wildcard results in a *
        ## so we must check always for the activity and *
        ## before we throw an exception

        foreach $owner (@owners)
        {
            foreach $user (@users)
            {
                $self->{PKI_REALM}->{$realm}->{ACL}->{$owner}->{$user}->{$activity} = 1;
                ##! 16: "permission: $realm, $owner, $user, $activity"
            }
        }
    }
    return 1;
}

sub __load_workflow_permissions {
    my $self   = shift;
    my $keys   = shift;
    ##! 1: 'start'
    my $realm  = $keys->{PKI_REALM};
    my $cfg_id = $keys->{CONFIG_ID};
    my $pkiid  = $self->{PKI_REALM}->{$realm}->{POS};

    my $perms = CTX('xml_config')->get_xpath_count(
                      XPATH   => [ 'pki_realm', 'acl', 'workflow_permissions' ],
                      COUNTER => [ $pkiid     , 0],
                      CONFIG_ID => $cfg_id,
                  );
    ##! 16: 'number of workflow_permissions entries: ' . $perms
    for (my $i=0; $i < $perms; $i++) {
        my @base_path = ( 'pki_realm', 'acl', 'workflow_permissions' );
        my @base_ctr  = ( $pkiid     , 0    , $i                    );
        my $role = CTX('xml_config')->get_xpath(
            XPATH     => [ @base_path, 'role' ],
            COUNTER   => [ @base_ctr , 0      ],
            CONFIG_ID => $cfg_id,
        );
        ##! 16: 'role: ' . $role
        my $servers = CTX('xml_config')->get_xpath_count(
            XPATH     => [ @base_path, 'server' ],
            COUNTER   => [ @base_ctr ],
            CONFIG_ID => $cfg_id,
        );
      SERVERS:
        for (my $ii = 0; $ii < $servers; $ii++) {
            my $server_name = CTX('xml_config')->get_xpath(
                XPATH     => [ @base_path, 'server', 'name' ],
                COUNTER   => [ @base_ctr , $ii     , 0      ],
                CONFIG_ID => $cfg_id,
            );
            ##! 16: 'server name: ' . $server_name
            if ($server_name ne '*' &&
                $server_name ne $self->{SERVER_NAME}) {
                ## we only need the permissions for _this_ server
                next SERVERS;
            }
            push @base_path, 'server';
            push @base_ctr , $ii;
            my $create_entries = CTX('xml_config')->get_xpath_count(
                XPATH     => [ @base_path, 'create' ],
                COUNTER   => [ @base_ctr,           ],
                CONFIG_ID => $cfg_id,
            );
            ##! 16: 'create entries: ' . Dumper $create_entries
            for (my $iii = 0; $iii < $create_entries; $iii++) {
                my $type = CTX('xml_config')->get_xpath(
                    XPATH     => [ @base_path, 'create', 'type' ],
                    COUNTER   => [ @base_ctr,  $iii    , 0      ],
                    CONFIG_ID => $cfg_id,
                );
                ##! 16: 'type: ' . $type
                $self->{PKI_REALM}->{$realm}->{ACL_WORKFLOW}->{$role}->{CREATE}->{$type} = 1;
            }
            my $read_entries = CTX('xml_config')->get_xpath_count(
                XPATH     => [ @base_path, 'read' ],
                COUNTER   => [ @base_ctr,           ],
                CONFIG_ID => $cfg_id,
            );
            ##! 16: 'read entries: ' . Dumper $read_entries
            for (my $iii = 0; $iii < $read_entries; $iii++) {
                my $type = CTX('xml_config')->get_xpath(
                    XPATH     => [ @base_path, 'read', 'type' ],
                    COUNTER   => [ @base_ctr,  $iii  , 0      ],
                    CONFIG_ID => $cfg_id,
                );
                ##! 16: 'type: ' . $type
                my $creator = '$self'; # conservative default, if nothing
                                       # is specified in the config, only
                                       # allow reading of own workflows
                eval {
                    $creator = CTX('xml_config')->get_xpath(
                        XPATH     => [ @base_path, 'read', 'creator' ],
                        COUNTER   => [ @base_ctr,  $iii  , 0         ],
                        CONFIG_ID => $cfg_id,
                    );
                };
                ##! 16: 'creator: ' . $creator
                my $context_show = '.*'; # liberal defaults: if nothing is
                my $context_hide = '';   # specified, allow to read complete
                                         # context
                eval {
                    $context_show = CTX('xml_config')->get_xpath(
                        XPATH     => [ @base_path, 'read', 'context_filter', 'show' ],
                        COUNTER   => [ @base_ctr,  $iii  , 0               , 0      ],
                        CONFIG_ID => $cfg_id,
                    );
                };
                eval {
                    $context_hide = CTX('xml_config')->get_xpath(
                        XPATH     => [ @base_path, 'read', 'context_filter', 'hide' ],
                        COUNTER   => [ @base_ctr,  $iii  , 0               , 0      ],
                        CONFIG_ID => $cfg_id,
                    );
                };
                ##! 16: 'context_show: ' . $context_show
                ##! 16: 'context_hide: ' . $context_hide

                $self->{PKI_REALM}->{$realm}->{ACL_WORKFLOW}->{$role}->{CREATE}->{$type} = 1;
                $self->{PKI_REALM}->{$realm}->{ACL_WORKFLOW}->{$role}->{READ}->{$type}->{CREATOR} = $creator;
                $self->{PKI_REALM}->{$realm}->{ACL_WORKFLOW}->{$role}->{READ}->{$type}->{CONTEXT}->{SHOW} = $context_show;
                $self->{PKI_REALM}->{$realm}->{ACL_WORKFLOW}->{$role}->{READ}->{$type}->{CONTEXT}->{HIDE} = $context_hide;
            }
        }
    }
    return 1;
}
########################################################################
##                          identify the user                         ##
########################################################################

sub authorize_workflow {
    my $self     = shift;
    my $arg_ref  = shift;
    my $action   = $arg_ref->{ACTION};
    ##! 16: 'action: ' . $action
    my $realm    = CTX('session')->get_pki_realm();
    ##! 16: 'realm: ' . $realm
    my $role     = CTX('session')->get_role();
    if ($role eq '') {
        $role = 'Anonymous';
    }
    ##! 16: 'role: ' . $role
    my $user     = CTX('session')->get_user();
    ##! 16: 'user: ' . $user

    ##! 64: 'ACL_WORKFLOW: ' . Dumper $self->{PKI_REALM}->{$realm}->{ACL_WORKFLOW}
    if ($action eq 'create') {
        my $type = $arg_ref->{TYPE};
        if (! exists $self->{PKI_REALM}->{$realm}->{ACL_WORKFLOW}
                          ->{$role}->{CREATE}->{$type}) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_CREATE_PERMISSION_DENIED',
                params  => {
                    'REALM'   => $realm,
                    'ROLE'    => $role,
                    'WF_TYPE' => $type,
                },
            );
        }
        return 1;
    } 
    elsif ($action eq 'read') {
        my $workflow = $arg_ref->{WORKFLOW};
        my $filter   = $arg_ref->{FILTER};
        my $type     = $workflow->type();
        if (! exists $self->{PKI_REALM}->{$realm}->{ACL_WORKFLOW}->{$role}
                          ->{READ}->{$type}) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_READ_PERMISSION_DENIED_NO_ACCESS_TO_TYPE',
            );
        }
        my $allowed_creator_re = $self->{PKI_REALM}->{$realm}->{ACL_WORKFLOW}->{$role}->{READ}->{$type}->{CREATOR};
        if ($allowed_creator_re eq '$self') {
            # this is a meta name, replace by current user name
            $allowed_creator_re = $user;
        }
        if ($allowed_creator_re) {
            ##! 16: 'allowed_creator_re: ' . $allowed_creator_re
            # if the allowed creator is defined and non-empty, check
            # it against the workflow creator
            my $wf_creator = $workflow->context()->param()->{creator};
            ##! 16: 'wf_creator: ' . $wf_creator
            if ($wf_creator !~ qr/$allowed_creator_re/ &&
                $wf_creator ne $allowed_creator_re) {
                ##! 16: 'workflow creator does not match allowed creator'
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_READ_PERMISSION_DENIED_WORKFLOW_CREATOR_NOT_ACCEPTABLE',
                );
            }
        }
        if (exists $self->{PKI_REALM}->{$realm}->{ACL_WORKFLOW}->{$role}->{READ}->{$type}->{CONTEXT} && $filter) {
            # context filtering is defined for this type, so
            # iterate over the context parameters and check them against
            # the show/hide configuration values
            my $show = $self->{PKI_REALM}->{$realm}->{ACL_WORKFLOW}->{$role}->{READ}->{$type}->{CONTEXT}->{SHOW};
            if (! defined $show) {
                $show = ''; # paranoid default: do not show anything
            }
            ##! 16: 'show: ' . $show
            my $hide = $self->{PKI_REALM}->{$realm}->{ACL_WORKFLOW}->{$role}->{READ}->{$type}->{CONTEXT}->{HIDE};
            if (! defined $hide) {
                $hide = ''; # liberal default: do not hide anything
            }
            my %original_params = %{ $workflow->context()->param() };
            # clear workflow context so that we can add the ones
            # that the user is allowed to see to it again ...
            $workflow->context()->clear_params();

            ##! 64: 'original_params before filtering: ' . Dumper \%original_params
            foreach my $key (keys %original_params) {
                ##! 64: 'key: ' . $key
                my $add = 1;
                if ($show) {
                    ##! 16: 'show present, checking against it'
                    if ($key !~ qr/$show/) {
                        ##! 16: 'key ' . $key . ' did not match ' . $show
                        $add = 0;
                    }
                }
                if ($hide) {
                    ##! 16: 'hide present, checking against it'
                    if ($key =~ qr/$hide/) {
                        ##! 16: 'key ' . $key . ' matches ' . $hide
                        $add = 0;
                    }
                }
                if ($add) {
                    ##! 16: 'adding key: ' . $key
                    $workflow->context()->param(
                        $key => $original_params{$key},
                    );
                }
            }
            ##! 64: 'workflow_context after filtering: ' . Dumper $workflow->context->param()
        }
        return 1;
    }
    else {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_UNKNOWN_ACTION',
            params  => {
                'ACTION' => $action,
            },
        );
    }
    # this code should be unreachable. In case it is not, throw an exception
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_INTERNAL_ERROR',
    );
}

sub authorize
{
    my $self = shift;
    my $keys = shift;

    ## we need the following things:
    ##     - PKI realm
    ##     - auth_role
    ##     - affected_role
    ##     - activity

    my $realm    = CTX('session')->get_pki_realm();
    my $user     = CTX('session')->get_role();
    my $owner    = "";
       $owner    = $keys->{AFFECTED_ROLE} if (exists $keys->{AFFECTED_ROLE} and
                                              defined $keys->{AFFECTED_ROLE});
    my $activity = $keys->{ACTIVITY};

    ##! 99: "user:realm:activity:owner - $user:$realm:$activity:$owner"

    if (! defined $activity)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_ACTIVITY_UNDEFINED",
            params  => {PKI_REALM     => $realm,
                        AFFECTED_ROLE => $owner,
                        AUTH_ROLE     => $user});
    }

    if ((! exists $self->{PKI_REALM}->{$realm}->{ROLES}->{$owner})
        && ($activity !~ m{ \A API:: }xms))
    { # FIXME: we need to figure out a way to find out the affected
      # role for API calls. For now, it is optional for authorization
      # of API calls
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_ILLEGAL_AFFECTED_ROLE",
            params  => {PKI_REALM     => $realm,
                        ACTIVITY      => $activity,
                        AFFECTED_ROLE => $owner,
                        AUTH_ROLE     => $user});
    }

    if (! exists $self->{PKI_REALM}->{$realm}->{ROLES}->{$user})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_ILLEGAL_AUTH_ROLE",
            params  => {PKI_REALM     => $realm,
                        ACTIVITY      => $activity,
                        AFFECTED_ROLE => $owner,
                        AUTH_ROLE     => $user});
    }

    my $granted;
    my $requested_activity = $activity;
    
  PERMISSION_CHECK:
    while ($requested_activity ne '') {
	if (exists $self->{PKI_REALM}->{$realm}->{ACL}->{$owner}->{$user}->{$requested_activity}) {
	    $granted = 1;
	    last PERMISSION_CHECK;
	}
	if ($requested_activity eq $activity) {
	    # replace Level1::Level2::activity by Level1::Level2::*
	    if (! ($requested_activity =~ s{ :: [^:]+ \z }{::*}xms)) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_MALFORMED_ACTIVITY",
		    params  => {
			PKI_REALM     => $realm,
			ACTIVITY      => $activity,
			AFFECTED_ROLE => $owner,
			AUTH_ROLE     => $user,
		    },
		    log => {
			logger => CTX('log'),
			priority => 'error',
			facility => 'auth',
		    },
		    );
	    }
	}
	elsif ($requested_activity =~ m{ ::\* \z }xms) {
	    # replace Level1::Level2::* by Level1::*
	    $requested_activity =~ s{ [^:]+ ::\* \z }{*}xms;
	}
	elsif ($requested_activity eq '*') {
	    # last step, replace '*' by ''
	    $requested_activity = '';
	}
	else {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_MALFORMED_ACTIVITY",
		params  => {
		    PKI_REALM     => $realm,
		    ACTIVITY      => $activity,
		    AFFECTED_ROLE => $owner,
		    AUTH_ROLE     => $user,
		},
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => 'auth',
		},
		);
	}
    }

    if (! $granted) {
        ##! 4: 'permission denied'
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_PERMISSION_DENIED",
            params  => {
		PKI_REALM     => $realm,
		ACTIVITY      => $activity,
		AFFECTED_ROLE => $owner,
		AUTH_ROLE     => $user,
	    },
	    log => {
		logger => CTX('log'),
		priority => 'info',
		facility => 'auth',
	    },
	    );
    }

    return 1;
}

sub get_roles
{
    my $self  = shift;
    return keys %{$self->{PKI_REALM}->{CTX('session')->get_pki_realm()}->{ROLES}};
}

sub get_servers
{
    my $self  = shift;
    return $self->{SERVER};
}

1;
__END__

=head1 Name

OpenXPKI::Server::ACL

=head1 Description

The ACL module implements the authorization for the OpenXPKI core system.

=head1 Functions

=head2 new

is the constructor of the module.
The constructor loads all ACLs of all PKI realms. Every PKI realm must include
an ACL section in its configuration. This configuration includes a definition
of all servers, all supported roles and all permissions.

=head2 authorize

is the function which grant the right to execute an activity. The function
needs two parameters ACTIVITY and AFFECTED_ROLE. The activity is the activity
which is performed by the workflow engine. The affected role is the role of
the object which is handled by the activity. If you create a request for
a certificate with the role "RA Operator" then the affected role is
"RA Operator".

The other needed parameters will be automatically determined via the active
session. It is not necessary to specify a PKI realm or the role of the logged
in user.

If the access is granted then function returns a true value. If the access
is denied then an exception is thrown.

=head2 get_roles

returns all available roles for the actual PKI realm.

=head2 get_servers

returns a hashref that lists all servers by PKI realm
