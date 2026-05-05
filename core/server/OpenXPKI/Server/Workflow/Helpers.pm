package OpenXPKI::Server::Workflow::Helpers;
use OpenXPKI;

use Workflow::Exception qw( configuration_error );

use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Context qw( CTX );

=head2 get_service_config_path

Helper to pull in information from the config layer with fallback to
I<interface>.I<server>.I<default_path>.

The method looks for the parameter I<config_path> first, if this is not
set, it reads I<interface> and I<server> from the context and adds the
value given as parameter to the method as last path component. If you
need to add more than one path element pass as array ref.

The return value is an array ref with the full path that can be given
to the config layer. A configuration_error will occur if the method
is unable to build the path due to missing input data.

=cut

sub get_service_config_path {

    my $workflow_class = shift;
    my $default_path = shift || '';

    my @prefix;

    if (my $config_path = $workflow_class->param('config_path')) {
        ##! 32: 'Explicit config path is set ' . $config_path
        @prefix = split /\./, $config_path;
    # auto create from interface and server in context if not set
    } elsif ($default_path) {
        my $context = $workflow_class->workflow()->context();
        my $interface = $context->param('interface');
        my $server = $context->param('server');

        if (!$server || !$interface) {
            configuration_error('Neither config_path nor interface/server is set!');
        }

        @prefix = ( $interface, $server );
        if (ref $default_path) {
            push @prefix, @{$default_path};
        } else {
            push @prefix, $default_path;
        }
        ##! 32: 'Autobuild config_path from interface ' . join ".", @prefix
    } else {
        configuration_error('Neither config_path nor ruleset_path is set!');
    }

    return \@prefix;

}

=head2 get_param_from_template

Helper to parse a _map parameter pattern into a value

Will handle dollar-sign notation for context values and
template strings.

Templates are parsed with input parameters set to

  {
    context => { full workflow context },
    workflow => {
      id => id of current workflow
    },
    session => {
      user => session user
      role => session role
      userinfo => userinfo hash from session
      pki_realm => current session pki_realm
    },
    hostname => node hostname
  }

You can pass additional template params as third argument

=cut

sub get_param_from_template {

    my $workflow_class = shift;
    my $args = shift;
    my $extra = shift || {};

    # We also support arrays or hashes here so we put the resolver into a sub
    my $resolve = sub {
        my $template = shift;
        if ($template =~ m{\A\$(\S+?)(\.(\S+))?\z}) {
            my $ctxkey = $1;
            my $subkey = $3 || '';
            ##! 16: 'load from context ' . $ctxkey . ' subkey: ' .$subkey
            my $ctx = $workflow_class->workflow()->context()->param( $ctxkey );
            if (!defined $ctx || $ctx eq '') {
                return $ctx;
            }
            if ($subkey) {
                if (ref $ctx eq 'HASH') {
                    return $ctx->{$subkey};
                } elsif (ref $ctx eq 'ARRAY' && $subkey =~ /\A\d+\z/) {
                    return $ctx->[$subkey];
                } else {
                    configuration_error("Subkey requested from _map but value is of wrong data type",
                        template => $template);
                }
            } else {
                return $ctx;
            }
        }

        # if it has no template sequence its a literal value
        if ($template !~ m{\[%}) {
            ##! 16: 'no template sequence - return as is: ' . $template
            return $template;
        }

        ##! 16: 'parse using tt ' . $template
        my $oxtt = OpenXPKI::Template->new();
        my $out = $oxtt->render( $template, {
            %$extra,
            context => $workflow_class->workflow()->context()->param(),
            workflow => {
                id => $workflow_class->workflow()->{id}
            },
            session => {
                user => CTX('session')->data->user,
                role => CTX('session')->data->role,
                userinfo => CTX('session')->data->userinfo,
                pki_realm => CTX('session')->data->pki_realm
            },
            hostname => CTX('config')->hostname,
        });
    };


    if (ref $args eq '') {
        return $resolve->($args);
    }

    if (ref $args eq 'ARRAY') {
        my @res = map {
            my $v = $resolve->($_);
            $v ne '' ? $v : ();
        } $args->@*;
        ##! 64:  \@res
        return \@res;

    }

    if (ref $args eq 'HASH') {
        my %res = map {
            my $v = $resolve->($args->{$_});
            $v ne '' ? ($_ => $v) : ();
        } keys $args->%*;
        ##! 64:  \%res
        return \%res;
    }

}

1;

__END__;