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
    $self->__load_config($arg_ref);
    $self->__init_engine();
    $self->__init_shell();
    $self->__init_command();
}

sub __init_local { # to be implemented in the children
}

sub __load_config {
    ##! 16: 'start'
    my $self = shift;
    my $ident = ident $self;
    my $arg_ref = shift;

    my $name        = $arg_ref->{NAME};
    my $realm_index = $arg_ref->{PKI_REALM_INDEX};
    my $type_path   = $arg_ref->{TOKEN_TYPE};
    my $type_index  = $arg_ref->{TOKEN_INDEX};
    my $certificate = $arg_ref->{CERTIFICATE};
    $params_of{$ident}->{SECRET} = $arg_ref->{SECRET};
    my $config_id   = $arg_ref->{CONFIG_ID};

    my $realm;
    my $type_id;

    $params_of{$ident}->{TMP} = $tmp_dir_of{$ident};


    eval {
        $realm = CTX('xml_config')->get_xpath(
            XPATH     => [ 'pki_realm' , 'name' ],
            COUNTER   => [ $realm_index, 0      ],
            CONFIG_ID => $config_id,
        );
    };
    if (! defined $realm) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOLKIT_COULD_NOT_READ_REALM_FROM_CONFIG',
            params => {
                'EVAL_ERROR' => $EVAL_ERROR,
            },
        );
    }
    ##! 16: 'realm: ' . $realm

    eval {
        $type_id = CTX('xml_config')->get_xpath(
            XPATH     => [ 'pki_realm' , $type_path , 'id' ],
            COUNTER   => [ $realm_index, $type_index, 0    ],
            CONFIG_ID => $config_id,
        );
    };
    if (! defined $type_id) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOLKIT_COULD_NOT_READ_TYPE_ID_FROM_CONFIG',
            params => {
                'EVAL_ERROR' => $EVAL_ERROR,
            },
        );
    }
    ##! 16: 'type_id: ' . $type_id

    # any existing key in this hash is considered optional in %token_args
    my %is_optional = ();

    # default tokens don't need a key
    # so do java keystore ones
    if ($type_path eq 'common' || $type_path eq 'createjavakeystore') {
        $is_optional{'KEY'} = 1;
    }
    # FIXME: currently unused attributes:
    # openca-sv
    # FIXME: engine_section is OpenSSL-specific
    foreach my $key (qw(backend
                        engine     shell         wrapper 
                        randfile
                        key
                        engine_section
                        key_store  engine_usage
                       )) {

	my $attribute_count;
	eval {
	    ##! 8: "try to get attribute_count"
	    $attribute_count = CTX('xml_config')->get_xpath_count (
            XPATH     => [ 'pki_realm', $type_path, 'token', $key ],
            COUNTER   => [ $realm_index, $type_index, 0 ],
            CONFIG_ID => $config_id,
        );
	    ##! 8: "attribute_count ::= ".$attribute_count
	};

	if (my $exc = OpenXPKI::Exception->caught()) {
	    ##! 8: "caught exception while reading config attribute $key"
	    # only pass exception if attribute is not optional
	    if (! $is_optional{uc($key)}) {
		##! 16: "argument $key is not optional, escalating"
		OpenXPKI::Exception->throw(
		    message  => "I18N_OPENXPKI_CRYPTO_TOOLKIT_INCOMPLETE_CONFIGURATION",
		    children => [ $exc ],
		    params   => {"NAME" => $name, 
			 	 "TYPE" => $type_path, 
			 	 "ATTRIBUTE" => $key,
		    },
		    );
	    }
	    $attribute_count = 0;
	}
        elsif ($EVAL_ERROR) {
	    ##! 8: "caught system exception while reading config attribute $key"
	    # FIXME: should we really throw an OpenXPKI exception here?
            OpenXPKI::Exception->throw (
                message => 'I18N_OPENXPKI_CRYPTO_TOOLKIT_LOAD_CONFIG_EVAL_ERROR',
                params  => { 'EVAL_ERROR' => $EVAL_ERROR,
                           },
            );
        }

	# multivalue attributes are not desired/supported
	if ($attribute_count > 1) {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_CRYPTO_TOOLKIT_LOAD_CONFIG_DUPLICATE_ATTRIBUTE',
		params  => {'NAME' => $name, 
			    'TYPE' => $type_path, 
			    'ATTRIBUTE' => $key,
		           },
            );
	}

	if ($attribute_count == 1) {
	    my $value = CTX('xml_config')->get_xpath(
            XPATH    => [ 'pki_realm', $type_path, 'token', $key ],
            COUNTER  => [ $realm_index, $type_index, 0, 0 ],
            CONFIG_ID => $config_id,
        );
    	    $params_of{$ident}->{uc($key)} = $value;
    }
    }
    if ($type_path eq 'ca' || $type_path eq 'scep' || $type_path eq 'password_safe') { # default tokens don't have a certificate
        # certificate files are no longer defined in token.xml, thus
        # create a temporary file with the certificate in it
        # every time a token is instantiated.
        # TODO: maybe just forget about the file and pass the certificate
        # as data where needed.
        if (!defined $certificate) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_TOOLKIT_CERTIFICATE_NOT_DEFINED',
            );
        }
        ##! 16: 'certificate: ' . $certificate
        my $fu = OpenXPKI::FileUtils->new();
        my $cert_filename = $fu->get_safe_tmpfile({
            TMP => $tmp_dir_of{$ident},
        });
        $fu->write_file({
            FILENAME => $cert_filename,
            CONTENT  => $certificate,
            FORCE    => 1,
        });
        chmod 0644, $cert_filename;
        $params_of{$ident}->{CERT} = $cert_filename;
    }
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
