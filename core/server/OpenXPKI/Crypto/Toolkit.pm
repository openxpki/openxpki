## OpenXPKI::Crypto::Toolkit
## Written 2006 by Alexander Klink for the OpenXPKI project
## based on OpenXPKI::Crypto::Backend::OpenSSL,
## written by Michael Bell for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Toolkit;

use strict;
use warnings;
use utf8; ## pack/unpack is too slow

use Class::Std;

use OpenXPKI::Crypto::CLI;
use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::FileUtils;
use English;
use Data::Dumper;

use File::Spec;

# attributes
my %token_type_of     :ATTR; # the token type
my %tmp_dir_of        :ATTR( :get<tmp_dir> );  # the temporary directory used
my %engine_of         :ATTR( :get<engine> :set<engine> ); # the engine used
my %cli_of            :ATTR( :get<cli> :set<cli> ); # the CLI object
my %params_of         :ATTR( :get<params> ); # a hash reference of parameters
my %command_params_of :ATTR( :get<command_params> ); # params for Command classes
my %base_class_of     :ATTR; # the current class we are in
my %shell_of          :ATTR( :get<shell> );
my %cert_identifier_of :ATTR( :get<cert_identifier> ); # the cert_idenfifier of the attached certificate

sub START {
    ##! 16: 'Toolkit start'
    my ($self, $ident, $arg_ref) = @_;

    $base_class_of{$ident} = ref $self;
    if ($base_class_of{$ident} eq 'OpenXPKI::Crypto::Toolkit') {
        # somebody tried to instantiate us, but we are supposed to be abstract.
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOLKIT_IS_ABSTRACT_CLASS',
        );
    }

    $token_type_of{$ident} = $arg_ref->{TOKEN_TYPE};
    my $requestedtmp = $arg_ref->{TMP};

    # determine temporary directory to use:
    # if a temporary directoy is specified, use it
    # else try /var/tmp (because potentially large files may be written that
    # are better left in the /var file system)
    # if /var/tmp does not exist fallback to /tmp

  CHECKTMPDIRS:
    for my $path ($requestedtmp,    # user's preference
          File::Spec->catfile('', 'var', 'tmp'), # suitable for large files
          File::Spec->catfile('', 'tmp'),        # present on all UNIXes
    ) {

    # directory must be readable & writable to be usable as tmp
    if (defined $path &&
        (-d $path) &&
        (-r $path) &&
        (-w $path)) {
        $tmp_dir_of{$ident} = $path;
        last CHECKTMPDIRS;
    }
    }

    if (! (exists $tmp_dir_of{$ident} && -d $tmp_dir_of{$ident}))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_TOOLKIT_TEMPORARY_DIRECTORY_UNAVAILABLE");
    }

    $command_params_of{$ident} = {};

    $self->__init_local();

    # We have two kinds of tokens with different config style
    # where system tokens do not have a "name" set.
    if ($arg_ref->{NAME}){
        $self->__load_config_realm_token($arg_ref);
    } else {
        $self->__load_config_system_token($arg_ref);
    }
    $self->__init_engine();
    $self->__init_shell();
    $self->__init_command();
}

sub __init_local { # to be implemented in the children
}

=head2 __load_config_system_token ()

Initialize system token

=cut

sub __load_config_system_token {
    ##! 16: 'start'
    my $self = shift;
    my $ident = ident $self;
    my $arg_ref = shift;

    my $type = $token_type_of{$ident};

    $params_of{$ident}->{TMP} = $tmp_dir_of{$ident};

    my $config = CTX('config');

    ##! 16: "Load system token $type"
    # FIXME - most of this params are useless for system tokens but creates errors when not set in the Backend::OpenSSL class
    foreach my $key (qw(backend
                    engine     shell         wrapper
                    randfile
                    engine_section engine_usage
                    key_store)) {

        $params_of{$ident}->{uc($key)} = $config->get("system.crypto.token.$type.$key") || '';
    }

}

=head2 __load_config_realm_token ( { NAME, SECRET, CERTIFICATE })

Initialize realm token defined by NAME (full alias as registered in the alias
table). SECRET can be omitted if the key is not protected by a passphrase.
CERTIFICATE is usually omitted and resolved internally by calling
get_certificate_for_alias. For situations where the alias can not be resolved
(testing), you can provide the result structure of the API call in the
CERTIFICATE parameter.

=cut

sub __load_config_realm_token {
    ##! 16: 'start'
    my $self = shift;
    my $ident = ident $self;
    my $arg_ref = shift;

    my $name = $arg_ref->{NAME};

    my $type = $token_type_of{$ident};

    $params_of{$ident}->{TMP} = $tmp_dir_of{$ident};

    my $config = CTX('config');
    # Load "real" crypto tokens (those with key material)
    ##! 16: "Load realm token of type $type, name $name"

    # Add the secret
    $params_of{$ident}->{SECRET} = $arg_ref->{SECRET} if ($arg_ref->{SECRET});


    # Magic inheritance code - see also TokenManager::__add_token
    # Use backend to test for instance / group
    my $backend_class = $config->get_inherit("crypto.token.$name.backend");

    my $config_name_group = $name;
    # Nothing found with the full token name, so try to load from the group name
    if (!$backend_class) {
        $config_name_group =~ /^(.+)-(\d+)$/;
        $config_name_group = $1;
        ##! 16: 'use group config ' . $config_name_group
        $backend_class = $config->get_inherit("crypto.token.$config_name_group.backend");
    }

    if (!$backend_class) {
         OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOLKIT_INCOMPLETE_CONFIGURATION_NO_BACKEND',
        );
    }

    $params_of{$ident}->{BACKEND} = $backend_class;

    my @keylist = (qw(engine shell wrapper randfile
                    engine_section engine_usage key key_store));

    foreach my $key (@keylist) {
        my $value = $config->get_inherit("crypto.token.$config_name_group.$key");
        $params_of{$ident}->{uc($key)} = $value if (defined $value);
    }

    # FIXME - most of this params are not usefull for all tokens, need a better error checking concept
    foreach my $key (@keylist) {
        if (not defined $params_of{$ident}->{uc($key)}) {
            OpenXPKI::Exception->throw(
                message  => "I18N_OPENXPKI_CRYPTO_TOOLKIT_INCOMPLETE_CONFIGURATION",
                params   => {
                    "NAME" => $name,
                    "TYPE" => $type,
                    "ATTRIBUTE" => $key,
            });
        }
    }


    # Use Template Toolkit to assemble the key name,
    # we offer the full alias, group and generation as vars (similar to cdp)
    # Split alias into generation and group name
    $name =~ /^(.*)-(\d+)$/;
    my $group = $1;
    my $generation = $2;

    my $template_vars = {
        'ALIAS' => $name,
        'GROUP' => $group,
        'GENERATION' => $generation
    };

    ##! 16: 'Building key name from template ' . $params_of{$ident}->{KEY}
    ##! 32: 'TT vars  ' . Dumper $template_vars

    my $tt = Template->new();
    my $output;
    $tt->process(\$params_of{$ident}->{KEY}, $template_vars, \$output);

    ##! 16: 'Key path ' . $output

    # Check for output
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_CRYPTO_TOOLKIT_CANT_BUILD_KEY_PATH',
        param => {

        }
    ) unless ($output);

    $params_of{$ident}->{KEY} = $output;

    my $certificate = $arg_ref->{CERTIFICATE};
    $certificate = CTX('api')->get_certificate_for_alias({ALIAS => $name}) unless($certificate);
    if (!defined $certificate || !$certificate->{DATA}) {
        # Should never show up if the api is not broken
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOLKIT_CERTIFICATE_NOT_DEFINED',
        );
    }

    $cert_identifier_of{$ident} = $certificate->{IDENTIFIER};

    ##! 16: 'certificate subject: ' . $certificate->{SUBJECT}
    ##! 64: 'certificate pem: ' .$certificate->{DATA}

    my $fu = OpenXPKI::FileUtils->new();
    my $cert_filename = $fu->get_safe_tmpfile({
        TMP => $tmp_dir_of{$ident},
    });
    $fu->write_file({
        FILENAME => $cert_filename,
        CONTENT  => $certificate->{DATA},
        FORCE    => 1,
    });
    chmod 0644, $cert_filename;
    $params_of{$ident}->{CERT} = $cert_filename;

    ##! 1: 'end'
}

sub __init_engine
{
    ##! 8: "start"
    my $self = shift;
    my $ident = ident $self;

    if (!exists $params_of{$ident}->{ENGINE} || $params_of{$ident}->{ENGINE} eq '') {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_TOOLKIT_ENGINE_UNDEFINED',
        );
    }

    my $engine = $base_class_of{$ident} . '::Engine::' . $params_of{$ident}->{ENGINE};
    eval "use $engine;";
    if ($EVAL_ERROR)
    {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_TOOLKIT_INIT_ENGINE_USE_FAILED',
            params  => { 'ERRVAL' => $EVAL_ERROR,
                       },
        );
    }
    $self->__instantiate_engine($engine);
}

# add XS parameters to OpenSSL part, set config in OpenSSL
sub __instantiate_engine {
    ##! 8: 'start'
    my $self = shift;
    my $ident = ident $self;
    my $engine = shift;

    delete $engine_of{$ident};
    $engine_of{$ident} = eval {
        $engine->new(
            %{$params_of{$ident}},
        )
    };
    if (my $exc = OpenXPKI::Exception->caught()) {
        OpenXPKI::Exception->throw (
            message  => "I18N_OPENXPKI_TOOLKIT_INIT_ENGINE_NEW_FAILED",
            children => [ $exc ]);
    } elsif ($EVAL_ERROR) {
        $EVAL_ERROR->rethrow();
    }
    ##! 8: 'end'
}

sub __init_shell
{
    ##! 8: "start"
    my $self = shift;
    my $ident = ident $self;

    if (not -e $params_of{$ident}->{SHELL}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_TOOLKIT_BINARY_NOT_FOUND',
        params => {
        SHELL => $params_of{$ident}->{SHELL},
        },
        );
    }
    elsif (not -x $params_of{$ident}->{SHELL}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_TOOLKIT_BINARY_NOT_EXECUTABLE',
        params => {
        SHELL => $params_of{$ident}->{SHELL},
        },
        );
    }
    else {
        $shell_of{$ident} = $params_of{$ident}->{SHELL};
    }
    my $wrapper = $engine_of{$ident}->get_wrapper();
    if ($wrapper ne '') {
        $shell_of{$ident} = $wrapper . ' ' . $shell_of{$ident};
    }

    my $cli_class = $base_class_of{$ident} . '::CLI';
    eval "use $cli_class;";
    if ($EVAL_ERROR ne '') {
        OpenXPKI::Exception->throw (
            message => 'I18N_OPENXPKI_TOOLKIT_INIT_SHELL_USE_FAILED',
            params  => { 'ERRVAL' => $EVAL_ERROR,
                       },
        );
    }
    $self->__instantiate_cli($cli_class);
    ##! 8: 'end'
}

sub __instantiate_cli {
    my $self = shift;
    my $ident = ident $self;
    my $cli_class = shift;

    eval {
        $cli_of{$ident} = $cli_class->new({
                               ENGINE => $engine_of{$ident},
                               SHELL  => $shell_of{$ident},
                               TMP    => $tmp_dir_of{$ident},
                            });
    };
    if (my $exc = OpenXPKI::Exception->caught()) {
        OpenXPKI::Exception->throw (
            message  => 'I18N_OPENXPKI_TOOLKIT_INSTANTIATE_CLI_FAILED',
            children => [ $exc ]);
    } elsif ($EVAL_ERROR) {
        $EVAL_ERROR->rethrow();
    }
}

sub __init_command {
    ##! 16: 'start'
    my $self = shift;
    my $ident = ident $self;

    # TODO: maybe throw RANDFILE away, it is too specific!
    foreach my $key (["TMP", "TMP"], ["RANDFILE", "RANDOM_FILE"]) {
        if (not exists $params_of{$ident}->{$key->[0]}) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TOOLKIT_MISSING_COMMAND_PARAM",
                params  => {"PARAM" => $key->[0]});
        }
        $self->get_command_params()->{$key->[1]} = $self->get_params()->{$key->[0]};
    }
    $self->get_command_params()->{ENGINE} = $self->get_engine();
    ##! 16: 'end'
}

sub __prepare_cli {
    my $self = shift;
    my $ident = ident $self;
    my $cmds = shift;

    ##! 16: Dumper($self)
    $self->get_cli()->prepare({
        COMMAND => $cmds,
    });
}

sub command {
    ##! 1: "start"
    my $self = shift;
    my $arg_ref = shift;
    my $ident = ident $self;

    my $cmd  = $base_class_of{$ident} . '::Command::' . $arg_ref->{COMMAND};
    delete $arg_ref->{COMMAND};

    eval "require $cmd";
    if ($EVAL_ERROR ne '') {
        OpenXPKI::Exception->throw(
            message  => 'I18N_OPENXPKI_TOOLKIT_COMMAND_REQUIRE_FAILED',
            params   => {'EVAL_ERROR' => $EVAL_ERROR},
        );
    }
    ##! 2: "Command: $cmd"

    my $ret = eval {
        my $cmd_ref = $cmd->new({
            %{$command_params_of{$ident}},
            %{$arg_ref},
            TOKEN_TYPE => $token_type_of{$ident},
            });
        my $cmds = $cmd_ref->get_command();

        my $cli_class = $base_class_of{$ident} . '::CLI';
        # instantiate a new CLI class so that the different
        # command calls during a token lifetime don't share
        # a stderr log file, which leads to multiple exceptions
        # for one error
        $self->__instantiate_cli($cli_class);
    if (ref $cmds ne 'HASH') {
        ##! 16: "standard invocation"
            $self->__prepare_cli($cmds);

        $cli_of{$ident}->execute();
    } else {
        # command returned a hash instead of a arrayref, this means
        # that we need to extract parameters for execute

        if (! exists $cmds->{COMMAND}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_TOOLKIT_COMMAND_MISSING_SUBPARAMETER_COMMAND");
        }
        if (! exists $cmds->{PARAMS}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_TOOLKIT_COMMAND_MISSING_SUBPARAMETER_PARAMS");
        }

            $self->__prepare_cli($cmds->{COMMAND});
        $cli_of{$ident}->execute({
                PARAMS => $cmds->{PARAMS},
        });
    }

        my $result = $cli_of{$ident}->get_result();
        ##! 128: 'before get_result()'
        $result = $cmd_ref->get_result($result);
        ##! 128: 'after get_result()'

        if ($cmd_ref->hide_output())
        {
            ##! 8: "successfully completed"
        } else {
            ##! 8: "successfully completed: $result"
        }

        $cmd_ref->cleanup();
        return $result;
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        ##! 16: 'exception: ' . Dumper $exc
        ##! 16: 'eval_error: ' . $EVAL_ERROR
        $cli_of{$ident}->cleanup(); ## this is safe
        OpenXPKI::Exception->throw (
            message  => "I18N_OPENXPKI_TOOLKIT_COMMAND_FAILED",
            params   => {"COMMAND" => $cmd},
            children => [ $exc ]);
    } elsif ($EVAL_ERROR ne '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_TOOLKIT_COMMAND_EVAL_ERROR',
            params => {
                'EVAL_ERROR' => $EVAL_ERROR,
            },
        );
    } else {
        ##! 4: "end"
        return $ret;
    }
}

###############################
##     BEGIN engine code     ##
###############################

sub online
{
    ##! 1: "start"
    my $self   = shift;
    my $ident = ident $self;
    return $self->get_engine()->online(@_);
}

sub key_usable
{
    ##! 1: "start"
    my $self   = shift;
    my $ident = ident $self;
    return $self->get_engine()->key_usable(@_);
}

sub login
{
    ##! 1: "start"
    my $self   = shift;
    my $ident = ident $self;
    return $self->get_engine()->login(@_);
}

sub logout
{
    ##! 1: "start"
    my $self   = shift;
    my $ident = ident $self;
    return $self->get_engine()->logout(@_);
}

sub get_certfile
{
    ##! 1: "start"
    my $self   = shift;
    my $ident = ident $self;
    return $self->get_engine()->get_certfile(@_);
}

sub get_chainfile
{
    ##! 1: "start"
    my $self   = shift;
    my $ident = ident $self;
    return $self->get_engine()->get_chainfile(@_);
}

#############################
##     END engine code     ##
#############################

1;
__END__

=head1 Name

OpenXPKI::Crypto::Toolkit - an ABSTRACT superclass for Backends and Tools

=head1 Description

This class provides an abstraction for both Backends and Tools, i.e.
OpenXPKI::Crypto::Backend::OpenSSL or OpenXPKI::Crypto::Tool::SCEP
Note that it can not be instantiated.

=head1 Functions

=head2 START

is the constructor (see Class:Std). It requires five basic parameters
which are described here. The other parameters are engine specific and
are described in the related engine documentation.

=over

=item * RANDFILE (file to store the random informations)

=item * SHELL (the binary to use)

=item * TMP (the used temporary directory which must be private)

=back

=head2 command

execute a  command. You must specify the name of the command
as first parameter followed by a hash with parameters.

=head1 See Also

OpenXPKI::Crypto::Backend::OpenSSL
OpenXPKI::Crypto::Tool::SCEP
