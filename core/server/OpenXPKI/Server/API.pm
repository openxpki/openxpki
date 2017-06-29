## OpenXPKI::Server::API.pm
##
## Written 2005, 2006, 2007 by Michael Bell, Martin Bartosch and
## Alexander Klink for the OpenXPKI project
## restructured 2006 by Alexander Klink for the OpenXPKI project
## Copyright (C) 2005-2007 by The OpenXPKI Project

package OpenXPKI::Server::API;

use strict;
use warnings;
use utf8;
use English;
use Benchmark ':hireswallclock';

use Class::Std;

use Data::Dumper;

use Regexp::Common;
use Params::Validate qw( validate :types );

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DN;
use OpenXPKI::Server::API::Default;
use OpenXPKI::Server::API::Object;
use OpenXPKI::Server::API::Profile;
use OpenXPKI::Server::API::Secret;
use OpenXPKI::Server::API::Token;
use OpenXPKI::Server::API::Housekeeping;
use OpenXPKI::Server::API::Workflow;
use OpenXPKI::Server::API::Smartcard;
use OpenXPKI::Server::API::UI;

my %external_of    :ATTR;
my %method_info_of :ATTR;
my %memoization_of :ATTR;
our $current_method;

sub BUILD {
    my ($self, $ident, $arg_ref) = @_;

    Params::Validate::validation_options(
    # let parameter validation errors throw a proper exception
    on_fail => sub {
        my $error = shift;

        OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_SERVER_API_INVALID_PARAMETER",
        params => {
            ERROR => $error,
            CALL => $current_method
        });
    },
    );
    if ($arg_ref->{EXTERNAL}) { # we are called externally, do ACL checks
        $external_of{$ident} = 1;
    }

    my $re_all               = qr{ \A .* \z }xms;
    my $re_alpha_string      = qr{ \A [ \w \- \. : \s ]* \z }xms;
    my $re_integer_string    = qr{ \A $RE{num}{int} \z }xms;
    my $re_int_or_hex_string = qr{ \A ([0-9]+|0x[0-9a-fA-F]+) \z }xms;
    my $re_boolean           = qr{ \A [01] \z }xms;
    my $re_base64_string     = qr{ \A [A-Za-z0-9\+/=_\-]* \z }xms;
    my $re_cert_string       = qr{ \A [A-Za-z0-9\+/=_\-\ \n]+ \z }xms;
    my $re_filename_string   = qr{ \A [A-Za-z0-9\+/=_\-\.]* \z }xms;
    my $re_image_format      = qr{ \A (ps|png|jpg|gif|cmapx|imap|svg|svgz|mif|fig|hpgl|pcl|NULL) \z }xms;
    my $re_cert_format       = qr{ \A (PEM|DER|TXT|PKCS7|HASH) \z }xms;
    my $re_crl_format        = qr{ \A (PEM|DER|TXT|HASH|RAW|FULLHASH|DBINFO) \z }xms;
    my $re_privkey_format    = qr{ \A (PKCS8_PEM|PKCS8_DER|OPENSSL_(PRIVKEY|RSA)|PKCS12|JAVA_KEYSTORE) \z }xms;
    # TODO - consider opening up re_sql_string even more, currently this means
    # that we can not search for unicode characters in certificate subjects,
    # for example ...
    my $re_sql_string        = qr{ \A [a-zA-Z0-9\@\-_\.\s\%\*\+\=\,\:\ ]* \z }xms;
    my $re_sql_field_name    = qr{ \A [A-Z0-9_\.]+ \z }xms;
    my $re_approval_msg_type = qr{ \A (CSR|CRR) \z }xms;
    my $re_approval_lang     = qr{ \A (de_DE|en_US|ru_RU) \z }xms;
    my $re_csr_format        = qr{ \A (PEM|DER|TXT) \z }xms;
    my $re_pkcs10            = qr{ \A [A-za-z0-9\+/=_\-\r\n\ ]+ \z}xms;

    $method_info_of{$ident} = {
        ### Default API
        'get_cert_identifier' => {
            class  => 'Default',
            params => {
                'CERT' => {
                    type  => SCALAR,
                    regex => $re_cert_string,
                },
            },
        },
        'get_default_token' => {
            class  => 'Token',
            params => {
            },
        },
        'get_token_alias_by_type' => {
            class  => 'Token',
            params => {
                'TYPE' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                'VALIDITY'  => {
                    type  => HASHREF,
                    optional => 1,
                },
            },
        },
        'get_token_alias_by_group' => {
            class  => 'Token',
            params => {
                'GROUP' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                'VALIDITY'  => {
                    type  => HASHREF,
                    optional => 1,
                },
            },
        },
        'list_active_aliases' => {
            class  => 'Token',
            params => {
                'GROUP' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                'TYPE' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                'VALIDITY'  => {
                    type  => HASHREF,
                    optional => 1,
                },
                'PKI_REALM' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                'CHECK_ONLINE' => {
                    type  => SCALAR,
                    regex => $re_boolean,
                    optional => 1,
                }
            },
        },
        'get_trust_anchors' => {
            class  => 'Token',
            params => {
                'PATH' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
            },
        },
        'get_certificate_for_alias' => {
            class  => 'Token',
            params => {
                'ALIAS' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
            },
        },
        'is_token_usable' => {
            class  => 'Token',
            params => {
                'ALIAS' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                'TYPE' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1
                },
                'ENGINE' => {
                    type  => SCALAR,
                    regex => $re_boolean,
                    optional => 1
                },
            },
        },
        'get_approval_message' => {
            class  => 'Default',
            params => {
                'TYPE' => {
                    type     => SCALAR,
                    regex    => $re_approval_msg_type,
                    optional => 1,
                },
                'WORKFLOW' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                'ID' => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                },
                'LANG' => {
                    type     => SCALAR,
                    regex    => $re_approval_lang,
                },
            },
            memoize => 1,
        },
        'get_head_version_id'  => {
            class  => 'Default',
            params => { },
        },
        'get_pki_realm' => {
            class  => 'Default',
            params => { },
        },
        'get_user' => {
            class  => 'Default',
            params => { },
        },
        'get_role' => {
            class  => 'Default',
            params => { },
        },
        'get_session_info' => {
            class  => 'Default',
            params => { },
        },
        'get_alg_names' => {
            class  => 'Default',
            params => { },
        },
        'get_param_names' => {
            class  => 'Default',
            params => {
                'KEYTYPE' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
            },
            memoize => 1,
        },
        'get_param_values' => {
            class  => 'Default',
            params => {
                'KEYTYPE' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                'PARAMNAME' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
            },
            memoize => 1,
        },
        'get_chain' => {
            class  => 'Default',
            params => {
                START_IDENTIFIER => {
                    type     => SCALAR,
                    regex    => $re_base64_string,
                },
                OUTFORMAT => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_cert_format,
                },
                BUNDLE => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
                KEEPROOT  => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
            },
        },
        'import_certificate' => {
            class  => 'Default',
            params => {
                DATA => {
                    type     => SCALAR,
                },
                ISSUER => {
                    type     => SCALAR,
                    regex    => $re_alpha_string,
                    optional => 1
                },
                PKI_REALM => {
                    type     => SCALAR,
                    regex    => $re_alpha_string,
                    optional => 1
                },
                UPDATE => {
                    type     => SCALAR,
                    regex    => $re_boolean,
                    optional => 1
                },
                FORCE_NOCHAIN => {
                    type     => SCALAR,
                    regex    => $re_boolean,
                    optional => 1
                },
                FORCE_ISSUER => {
                    type     => SCALAR,
                    regex    => $re_boolean,
                    optional => 1
                },
                FORCE_NOVERIFY => {
                    type     => SCALAR,
                    regex    => $re_boolean,
                    optional => 1
                },
                REVOKED => {
                    type     => SCALAR,
                    regex    => $re_boolean,
                    optional => 1
                },
            }
        },
        'import_chain' => {
            class  => 'Default',
            params => {
                DATA => {
                    type     => SCALAR | ARRAYREF,
                },
                PKI_REALM => {
                    type     => SCALAR,
                    regex    => $re_alpha_string,
                    optional => 1
                },
                IMPORT_ROOT => {
                    type     => SCALAR,
                    regex    => $re_boolean,
                    optional => 1
                },
                FORCE_NOCHAIN => {
                    type     => SCALAR,
                    regex    => $re_boolean,
                    optional => 1
                },
            }
        },
        'get_ca_list' => {
            class  => 'Token',
            params => {
                PKI_REALM => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
            },
        },
        'generate_key' => {
            class  => 'Object',
            params => {
                PASSWD => {
                    type     => SCALAR,
                },
                KEY_ALG => {
                    type     => SCALAR,
                    optional => 1
                },
                ENC_ALG => {
                    type     => SCALAR,
                    optional => 1
                },
                PARAMS => {
                    type     => HASHREF,
                    optional => 1
                }
            },
        },
        'get_ca_cert' => {
            class  => 'Object',
            params => {
                IDENTIFIER => {
                    type     => SCALAR,
                    regex    => $re_base64_string,
                }
            },
        },
        'get_cert' => {
            class  => 'Object',
            params => {
                IDENTIFIER => {
                    type     => SCALAR,
                    regex    => $re_base64_string,
                },
                FORMAT   => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_alpha_string,
                },
            },
        },
        'get_cert_attributes' => {
            class  => 'Object',
            params => {
                IDENTIFIER => {
                    type     => SCALAR,
                    regex    => $re_base64_string,
                },
                ATTRIBUTE => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_sql_string,
                },
            }
        },
        'get_cert_actions' => {
            class  => 'Object',
            params => {
                IDENTIFIER => {
                    type     => SCALAR,
                    regex    => $re_base64_string,
                },
                ROLE => {
                    type     => SCALAR,
                    optional => 1
                }
            }
        },
        'is_certificate_owner' => {
            class  => 'Object',
            params => {
                IDENTIFIER => {
                    type     => SCALAR,
                    regex    => $re_base64_string,
                },
                USER => {
                    type     => SCALAR,
                    optional => 1
                }
            }
        },
        'get_profile_for_cert' => {
            class  => 'Object',
            params => {
                IDENTIFIER => {
                    type     => SCALAR,
                    regex    => $re_base64_string,
                },
            }
        },
        'private_key_exists_for_cert' => {
            class  => 'Object',
            params => {
                IDENTIFIER => {
                    type  => SCALAR,
                    regex => $re_base64_string,
                },
            },
        },
        'get_private_key_for_cert' => {
            class  => 'Object',
            params => {
                IDENTIFIER => {
                    type  => SCALAR,
                    regex => $re_base64_string,
                },
                FORMAT => {
                    type  => SCALAR,
                    regex => $re_privkey_format,
                },
                PASSWORD => {
                    type     => SCALAR,
                    # regex => ???
                },
                PASSOUT=> {
                    type     => SCALAR,
                    optional => 1,
                    # regex => ???
                },
                NOPASSWD => {
                    type     => SCALAR,
                    optional => 1,
                    regex => $re_boolean,
                },
                KEEPROOT => {
                    type     => SCALAR,
                    optional => 1,
                    regex => $re_boolean,
                },
                CSP      => {
                    type     => SCALAR,
                    regex    => $re_alpha_string,
                    optional => 1,
                },
                ALIAS    => {
                    type     => SCALAR,
                    regex    => $re_alpha_string,
                    optional => 1,
                },
            },
        },
        'get_crl' => {
            class  => 'Object',
            params => {
                SERIAL => {
                    type     => SCALAR,
                    regex    => $re_integer_string,
                    optional => 1,
                },
                CRL_KEY => {
                    type     => SCALAR,
                    regex    => $re_integer_string,
                    optional => 1,
                },
                FORMAT => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_crl_format,
                },
                PKI_REALM => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
            },
        },
        'get_crl_list' => {
            class  => 'Object',
            params => {
                'ISSUER' => {
                    type     => SCALAR,
                    regex    => $re_base64_string,
                    optional => 1,
                },
                'PKI_REALM' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                'FORMAT' => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_crl_format,
                },
                VALID_AT => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                LIMIT  => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                    optional => 1,
                },
            },
        },
        'import_crl' => {
            class  => 'Object',
            params => {
                'DATA' => {
                    type     => SCALAR,
                },
                ISSUER => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_base64_string,
                },
            },
        },
        'get_random' => {
            class  => 'Default',
            params => {
                'LENGTH' => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                },
            },
        },
        'search_cert_count' => {
            class  => 'Object',
            params => {
                IDENTIFIER => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_base64_string,
                },
                EMAIL => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_sql_string,
                },
                SUBJECT => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_sql_string,
                },
                ISSUER_DN => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_sql_string,
                },
                ISSUER_IDENTIFIER => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_base64_string,
                },
                SUBJECT_KEY_IDENTIFIER => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                AUTHORITY_KEY_IDENTIFIER => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                CSR_SERIAL => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_integer_string,
                },
                CERT_SERIAL => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_int_or_hex_string,
                },
                'PKI_REALM' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                NOTBEFORE => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_integer_string,
                },
                NOTAFTER => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_integer_string,
                },
                PROFILE => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                CERT_ATTRIBUTES => {
                    type     => ARRAYREF,
                    optional => 1,
                },
                VALID_AT => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_integer_string,
                },
                STATUS => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_sql_string,
                },
                ENTITY_ONLY => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                }
            },
        },
        'search_cert' => {
            class  => 'Object',
            params => {
                IDENTIFIER => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_base64_string,
                },
                EMAIL => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_sql_string,
                },
                SUBJECT => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_sql_string,
                },
                ISSUER_DN => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_sql_string,
                },
                ISSUER_IDENTIFIER => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_base64_string,
                },
                CSR_SERIAL => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_integer_string,
                },
                CERT_SERIAL => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_int_or_hex_string,
                },
                'PKI_REALM' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                 SUBJECT_KEY_IDENTIFIER => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                AUTHORITY_KEY_IDENTIFIER => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                NOTBEFORE => {
                    type     => SCALAR|HASHREF,
                    optional => 1,
                },
                NOTAFTER => {
                    type     => SCALAR|HASHREF,
                    optional => 1,
                },
                PROFILE => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                CERT_ATTRIBUTES => {
                    type     => ARRAYREF,
                    optional => 1,
                },
                LIMIT => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_integer_string,
                },
                START => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_integer_string,
                },
                VALID_AT => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_integer_string,
                },
                STATUS => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_sql_string,
                },
                ENTITY_ONLY => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
                ORDER => {
                    type  => SCALAR,
                    regex => $re_sql_field_name,
                    optional => 1,
                },
                REVERSE => {
                    type  => SCALAR,
                    regex => $re_boolean,
                    optional => 1,
                },
            },
        },
        'control_watchdog' => {
            class => 'Object',
            params => {
                'ACTION' => {
                    type => SCALAR,
                }
            }
        },
        'convert_csr' => {
            class  => 'Default',
            params => {
                DATA => {
                    type => SCALAR,
                },
                IN => {
                    type  => SCALAR,
                    regex => $re_csr_format,
                },
                OUT => {
                    type  => SCALAR,
                    regex => $re_csr_format,
                },
            },
        },
        'convert_certificate' => {
            class  => 'Default',
            params => {
                DATA => {
                    type => SCALAR,
                },
                IN => {
                    type  => SCALAR,
                    regex => $re_csr_format,
                },
                OUT => {
                    type  => SCALAR,
                    regex => $re_csr_format,
                },
            },
        },
        'send_notification' => {
            class  => 'Default',
            params => {
                MESSAGE => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                PARAMS => {
                    type   => HASHREF,
                    optional => 1,
                },
            },
        },

        ## Profile API
        'get_cert_profiles' => {
            class  => 'Profile',
            params => {
                'NOHIDE' => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
            },
            memoize => 1,
        },
        'get_cert_subject_profiles' => {
            class  => 'Profile',
            params => {
                PROFILE => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                'NOHIDE' => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
            },
            memoize => 1,
        },
        'get_cert_subject_styles' => {
            class  => 'Profile',
            params => {
                PROFILE => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
            },
            memoize => 1,
        },
        'list_used_profiles' => {
            class  => 'Profile',
            params => {
                PKI_REALM => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
            }
        },
        'get_additional_information_fields' => {
            class  => 'Profile',
            params => {
            },
            memoize => 1,
        },
        'get_field_definition' => {
            class  => 'Profile',
            params => {
                PROFILE => {
                    type     => SCALAR,
                    regex    => $re_alpha_string
                },
                FIELDS => {
                    type     => ARRAYREF,
                    optional => 1,
                },
                STYLE => {
                    type     => SCALAR,
                    optional => 1,
                },
                SECTION => {
                    type     => SCALAR,
                    optional => 1,
                },
            },
        },
        'render_subject_from_template' => {
            class  => 'Profile',
            params => {
                PROFILE => {
                    type     => SCALAR,
                    regex    => $re_alpha_string
                },
                STYLE => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_alpha_string,
                },
                VARS => {
                    type     => HASHREF,
                },
            },
        },
        'render_san_from_template' => {
            class  => 'Profile',
            params => {
                PROFILE => {
                    type     => SCALAR,
                    regex    => $re_alpha_string
                },
                STYLE => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_alpha_string,
                },
                VARS => {
                    type     => HASHREF,
                },
                ADDITIONAL => {
                    type     => HASHREF | UNDEF,
                    optional => 1
                },
            },
        },
        'list_supported_san' => {
            class  => 'Profile',
            params => {}
        },
        'render_metadata_from_template'=> {
            class  => 'Profile',
            params => {
                PROFILE => {
                    type     => SCALAR,
                    regex    => $re_alpha_string
                },
                STYLE => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_alpha_string,
                },
                VARS => {
                    type     => HASHREF,
                },
            },
        },
        'get_key_algs' => {
            class  => 'Profile',
            params => {
                PROFILE => {
                    type     => SCALAR,
                    regex    => $re_alpha_string
                },
                NOHIDE => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
            }
        },
        'get_key_enc' => {
            class  => 'Profile',
            params => {
                PROFILE => {
                    type     => SCALAR,
                    regex    => $re_alpha_string
                },
                NOHIDE => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
            }
        },
        'get_key_params' => {
            class  => 'Profile',
            params => {
                PROFILE => {
                    type     => SCALAR,
                    regex    => $re_alpha_string
                },
                ALG => {
                    type     => SCALAR,
                    regex    => $re_alpha_string,
                    optional => 1,
                },
                NOHIDE => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
            }
        },

        ### Object API
        'get_csr_info_hash_from_data' => {
            class  => 'Object',
            params => {
                DATA => {
                    type     => SCALAR, # TODO: regexp?
                },
            },
        },
        'get_key_identifier_from_data' => {
            class  => 'Object',
            params => {
                DATA => {
                    type    => SCALAR,
                },
                FORMAT => {
                    type    => SCALAR,
                    regex   => qr{ \A (PKCS10) \z }xms,
                }

            },
        },
        'set_data_pool_entry' => {
            class  => 'Object',
            params => {
                'PKI_REALM' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                'NAMESPACE' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                'EXPIRATION_DATE' => {
                    type  => SCALAR | UNDEF,
                    regex => $re_integer_string,
                    optional => 1,
                },
                'ENCRYPT' => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                    optional => 1,
                },
                'KEY' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                'VALUE' => {
                    type  => SCALAR | UNDEF,
                    regex => $re_all,
                },
                'FORCE' => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                    optional => 1,
                },
                'COMMIT' => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                    optional => 1,
                },
            },
        },
        'get_data_pool_entry' => {
            class  => 'Object',
            params => {
                'PKI_REALM' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                'NAMESPACE' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                'KEY' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
            },
        },
        'modify_data_pool_entry' => {
            class  => 'Object',
            params => {
                'PKI_REALM' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                'NAMESPACE' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                'KEY' => {
                    type  => SCALAR,
                    regex => qr{ \A \$? [ \w \- \. : \s ]* \z }xms,
                },
                'NEWKEY' => {
                    type  => SCALAR,
                    regex => qr{ \A \$? [ \w \- \. : \s ]* \z }xms,
                },
                'EXPIRATION_DATE' => {
                    type  => SCALAR | UNDEF,
            # allow integers but also empty string (undef...)
                    regex => qr{ \A $RE{num}{int}* \z }xms,
                    optional => 1,
                },
            },
        },
        'list_data_pool_entries' => {
            class  => 'Object',
            params => {
                'PKI_REALM' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                'NAMESPACE' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                'LIMIT'  => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                    optional => 1,
                },
            },
        },
        'get_report_list' => {
            class  => 'Object',
            params => {
                'NAME' => {
                    type  => SCALAR,
                    regex => $re_sql_string,
                    optional => 1,
                },
                'MAXAGE' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                'COLUMNS' => {
                    type  => SCALAR | ARRAYREF,
                    optional => 1,
                }
            }
        },
        'get_report' => {
            class  => 'Object',
            params => {
                'NAME' => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                'FORMAT' => {
                    type  => SCALAR,
                    regex => qr{ ALL|HASH|DATA }xms,
                    optional => 1,
                },
            }
        },
        'validate_certificate' => {
            class  => 'Object',
            params => {
                'PEM' => {
                    type  => SCALAR | ARRAYREF,
                    optional => 1,
                },
                'PKCS7' => {
                    type  => SCALAR,
                    regex => $re_cert_string,
                    optional => 1,
                },
                'ANCHOR' => {
                    type  => ARRAYREF,
                    optional => 1,
                },
                'NOCRL' => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                    optional => 1,
                },
            }
        },

        ### Housekeeping API
        'purge_application_log' => {
            class => 'Housekeeping',
            params => {
                MAXAGE => {
                    type => SCALAR,
                    regex => $re_integer_string,
                },
                LEGACY => {
                    type  => SCALAR,
                    regex => $re_boolean,
                    optional => 1,
                },
            },
        },

        ### Workflow API
        'get_workflow_instance_types' => {
            class  => 'Workflow',
            params => {}
        },
        'list_workflow_titles' => {
            class  => 'Workflow',
            params => { },
            memoize => 1,
        },
        'get_workflow_type_for_id' => {
            class  => 'Workflow',
            params => {
                ID => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                },
            },
        },
        'get_workflow_info' => {
            class  => 'Workflow',
            params => {
                WORKFLOW => {
                    type     => SCALAR|HASHREF,
                    regex    => $re_alpha_string,
                    optional => 1,
                },
                ID => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                    optional => 1,
                },
                TYPE => {
                    type     => SCALAR,
                    regex    => $re_alpha_string,
                    optional => 1,
                },
                ACTIVITY => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                UIINFO => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
                ATTRIBUTE => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
            },
        },
        'get_workflow_log' => {
            class  => 'Workflow',
            params => {
                ID => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                },
                REVERSE => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
                LIMIT => {
                    type  => SCALAR,
                    optional => 1,
                    regex => $re_integer_string,
                },
            },
        },
        'get_workflow_creator' =>{
            class  => 'Workflow',
            params => {
                ID => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                },
            }
        },
        'get_workflow_history' => {
            class  => 'Workflow',
            params => {
                ID => {
                        type  => SCALAR,
                        regex => $re_integer_string,
                },
                NOACL => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
            },
        },
        'execute_workflow_activity' => {
            class  => 'Workflow',
            params => {
                WORKFLOW => {
                    type     => SCALAR,
                    regex    => $re_alpha_string,
                    optional => 1,
                },
                ID => {
                    type     => SCALAR,
                    regex    => $re_integer_string,
                    optional => 1,
                },
                ACTIVITY => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                PARAMS   => {
                    type     => HASHREF,
                    optional => 1,
                },
                UIINFO => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
                ASYNC => {
                    type     => SCALAR,
                    regex    => qr{ fork|watch }x,
                    optional => 1,
                },
            },
        },
        'create_workflow_instance' => {
            class  => 'Workflow',
            params => {
                WORKFLOW => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                PARAMS => {
                    type     => HASHREF,
                    optional => 1,
                },
                UIINFO => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_boolean,
                },
            },
        },
        'fail_workflow' => {
            class  => 'Workflow',
            params => {
                WORKFLOW => {
                    type     => SCALAR,
                    regex    => $re_alpha_string,
                    optional => 1,
                },
                ID => {
                    type     => SCALAR,
                    regex    => $re_integer_string,
                },
                REASON => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                ERROR => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
            },
        },
        'wakeup_workflow' => {
            class  => 'Workflow',
            params => {
                WORKFLOW => {
                    type     => SCALAR,
                    regex    => $re_alpha_string,
                    optional => 1,
                },
                ID => {
                    type     => SCALAR,
                    regex    => $re_integer_string,
                },
                ASYNC => {
                    type     => SCALAR,
                    regex    => qr{ fork|watch }x,
                    optional => 1,
                },
            },
        },
        'resume_workflow' => {
            class  => 'Workflow',
            params => {
                WORKFLOW => {
                    type     => SCALAR,
                    regex    => $re_alpha_string,
                    optional => 1,
                },
                ID => {
                    type     => SCALAR,
                    regex    => $re_integer_string,
                },
                ASYNC => {
                    type     => SCALAR,
                    regex    => qr{ fork|watch }x,
                    optional => 1,
                },
            },
        },
        'get_workflow_activities' => {
            class  => 'Workflow',
            params => {
                WORKFLOW => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                },
                ID => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                },
            },
        },
        'get_workflow_activities_params' => {
            class => 'Workflow',
            params => {
                WORKFLOW => {
                    type => SCALAR,
                    regex => $re_alpha_string,
                },
                ID => {
                    type => SCALAR,
                    regex => $re_integer_string,
                },
            },
        },
        'search_workflow_instances' => {
            class  => 'Workflow',
            params => {
                SERIAL => {
                    type     => ARRAYREF | UNDEF,
                    optional => 1,
                },
                ATTRIBUTE => {
                    type     => ARRAYREF | UNDEF,
                    optional => 1,
                },
                TYPE => {
                    type     => SCALAR | ARRAYREF,
                #    regex    => $re_alpha_string,
                #    parameter content is checked in the method itself
                #    because we can't check the array ref entries here
                    optional => 1,
                },
                STATE => {
                    type     => SCALAR | ARRAYREF,
                #    regex    => $re_alpha_string,
                #    parameter content is checked in the method itself
                #    because we can't check the array ref entries here
                    optional => 1,
                },
                PROC_STATE => {
                    type     => SCALAR,
                    regex    => $re_alpha_string,
                    optional => 1,
                },
                LIMIT => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                    optional => 1,
                },
                START => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                    optional => 1,
                },
                ORDER => {
                    type  => SCALAR,
                    regex => $re_sql_field_name,
                    optional => 1,
                },
                REVERSE => {
                    type  => SCALAR,
                    regex => $re_boolean,
                    optional => 1,
                },
                PKI_REALM => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
            },
        },
        'search_workflow_instances_count' => {
            class  => 'Workflow',
            params => {
                SERIAL => {
                    type     => ARRAYREF | UNDEF,
                    optional => 1,
                },
                ATTRIBUTE => {
                    type     => ARRAYREF | UNDEF,
                    optional => 1,
                },
                TYPE => {
                    type     => SCALAR | ARRAYREF,
                #    regex    => $re_alpha_string,
                #    parameter content is checked in the method itself
                #    because we can't check the array ref entries here
                    optional => 1,
                },
                STATE => {
                    type     => SCALAR | ARRAYREF,
                #    regex    => $re_alpha_string,
                #    parameter content is checked in the method itself
                #    because we can't check the array ref entries here
                    optional => 1,
                },
                PROC_STATE => {
                    type     => SCALAR,
                    regex    => $re_alpha_string,
                    optional => 1,
                },
                PKI_REALM => {
                    type  => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
            },
        },
        'get_secrets' => {
            class  => 'Secret',
            params => { },
            memoize => 1,
        },
        'is_secret_complete' => {
            class  => 'Secret',
            params => {
                SECRET => {
                    type  => SCALAR,
                    regex => $re_alpha_string
                }
            }
        },
        'set_secret_part' => {
            class  => 'Secret',
            params => {
                SECRET => {
                    type  => SCALAR,
                    regex => $re_alpha_string
                },
                PART => {
                    type     => SCALAR,
                    optional => 1,
                    regex    => $re_integer_string
                },
                VALUE => {
                    type  => SCALAR,
                    regex => $re_all
                }
            }
        },
        'clear_secret' => {
            class  => 'Secret',
            params => {
                SECRET => {
                    type  => SCALAR,
                    regex => $re_alpha_string
                },
            },
        },

        ### Smartcard API
        'sc_analyze_certificate' => {
            class  => 'Smartcard',
            params => {
                'DATA' => {
                    type  => SCALAR,
                    regex => $re_cert_string,
                },
                'CERTFORMAT' => {
                    type  => SCALAR,
                    regex => $re_cert_string,
                },
                'DONTPARSE' => {
                    type  => SCALAR,
                    regex => $re_integer_string,
                },
            },
        },

        'sc_parse_certificates' => {
            class  => 'Smartcard',
            params => {
                'CERTS' => {
                    type  => ARRAYREF,
                    #regex => qr{ \A [A-Za-z0-9\+/=_\-\ \n]+ \z }xms;,
                },
                'CERTFORMAT' => {
                    type  => SCALAR,
                    regex => $re_cert_string,
                    optional => 1,
                },
            },
        },

        'sc_analyze_smartcard' => {
            class  => 'Smartcard',
            params => {
                'CERTS' => {
                    type  => ARRAYREF,
            #regex => $re_cert_string,
               },
                'CERTFORMAT' => {
                    type  => SCALAR,
                    regex => $re_cert_string,
                    optional => 1,
                },
                'SMARTCARDID' => {
                    type => SCALAR,
                    regex => $re_alpha_string,
                },
                'SMARTCHIPID' => {
                    type => SCALAR,
                    regex => $re_alpha_string,
                    optional => 1,
                },
                'USERID' => {
                    type => SCALAR,
                    regex => $re_sql_string,
                    optional => 1,
                },
                'WORKFLOW_TYPES' => {
                    type => ARRAYREF,
                    optional => 1,
                },
            },
        },

        # Methods for UI
        'get_ui_system_status' => {
            class  => 'UI',
            params => {
                'ITEMS' => {
                    type  => ARRAYREF,
                    optional => 1,
               },
            }
        },
        'list_process' => {
            class  => 'UI',
            params => {
            }
        },
        'get_menu' => {
            class  => 'UI',
            params => {
            }
        },
        'get_motd' => {
            class  => 'UI',
            params => {
                'ROLE' => {
                    type => SCALAR,
                    optional => 1,
                },
            }
        },
        # this is a workaround and should be refactored, see #283
        'render_template' => {
            class  => 'UI',
            params => {
                'TEMPLATE' => {
                    type => SCALAR,
                },
                'PARAMS' => {
                    type => HASHREF,
                    optional => 1,
                },
            }
        }
    };
}

sub AUTOMETHOD {
    my ($self, $ident, @args) = @_;

    my $method_name = $_;

    ##! 16: 'method name: ' . $method_name
    return sub {
        if (!exists $method_info_of{$ident}->{$method_name}) {

            ##! 16: 'exception'
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_INVALID_METHOD_CALLED',
                params  => {
                    'METHOD_NAME' => $method_name,
                },
        log => {
            priority => 'info',
            facility => 'system',
        },
            );
        }
        my $class         = $method_info_of{$ident}->{$method_name}->{class};
        my $valid_params  = $method_info_of{$ident}->{$method_name}->{params};

        ##! 16: 'args: ' . Dumper(\@args)
        # do parameter checking
        $current_method = $method_name;
        if (scalar @args > 1 || defined $args[0]) {
            validate(
                @args,
                $valid_params,
            );
        }


        # ACL checking - FIXME - ACL - need implementation
        if (0 && $external_of{$ident}) { # do ACL checking
            my $affected_role
                = $method_info_of{$ident}->{$method_name}->{affected_role};
            my $acl_hashref = {
                ACTIVITY      => "API::" . $class . "::" . $method_name,
            };
            if (defined $affected_role) {
                # FIXME: optional for now, as we don't have a good way to
                # figure out which role is affected by a certain API call
                $acl_hashref->{AFFECTED_ROLE} = $affected_role;
            }
            eval {
                #FIXME - ACL checking is disabled
                #CTX('acl')->authorize($acl_hashref);
            # logging is done in ACL class
            };

            if (my $exc = OpenXPKI::Exception->caught()) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_ACL_CHECK_FAILED',
                    params  => {
                        'EXCEPTION' => $exc->message(),
                        'PARAMS'    => $exc->params(),
                    },
                );
            }
            elsif ($EVAL_ERROR) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_ACL_CHECK_FAILED',
                    params  => {
                        'EVAL_ERROR' => $EVAL_ERROR,
                    },
                );
            }
        }

        CTX('log')->system()->debug("Method '$method_name' called via API");


        my $memoization_key;
        if (exists $method_info_of{$ident}->{$method_name}->{memoize} &&
            $method_info_of{$ident}->{$method_name}->{memoize}) {
            ##! 128: 'method ' . $method_name . ' may be memoized'
            $memoization_key = '';
            foreach my $key (keys %{ $args[0] }) {
                $memoization_key .= $key . '=' . $args[0]->{$key};
            }
            ##! 128: 'args: ' . Dumper \@args
            if ($memoization_key eq '') {
                # special key is needed if no arguments are passed
                $memoization_key = 'no_args';
            }
            ##! 128: 'memoization key: ' . $memoization_key
            if (exists $memoization_of{$ident}->{$method_name}->{$memoization_key}) {
                ##! 128: 'cache hit for method ' . $method_name . ' / memo key: ' . $memoization_key
                return $memoization_of{$ident}->{$method_name}->{$memoization_key};
            }
        }
        ##! 128: 'cache miss for method ' . $method_name . ' / memo key: ' . $memoization_key
        # call corresponding method
        my $openxpki_class = "OpenXPKI::Server::API::" . $class;
        ##! 64: 'Calling ' . $openxpki_class . '->' . $method_name
        my $t0 = Benchmark->new();
        my $result = $openxpki_class->$method_name(@args);
        my $t1 = Benchmark->new();
        ##! 64: 'The call of ' . $openxpki_class . '->' . $method_name . ' took ' . timestr(timediff($t1, $t0))
        if (defined $memoization_key) {
            # if a memoization key is defined, we want to memoize the result
            return $memoization_of{$ident}->{$method_name}->{$memoization_key} = $result;
        }
        return $result;
    };
}

sub can {

    ##! 1: 'Start'

    # WARNING - we just do not support "can" for autoloaded methods for
    # now. This is a workaround to fix an interference between Carp
    # and the automethod in this API, see github ticket #415

    # TODO: API handling should be improved

    return undef;
}

###########################################################################

1;
__END__

=head1 Name

OpenXPKI::Server::API

=head1 Description

This is the interface which should be used by all user interfaces of OpenXPKI.
A user interface MUST NOT access the server directly. The only allowed
access is via this API. Any function which is not available in this API is
not for public use.
The API gets access to the server via the 'server' context object. This
object must be set before instantiating the API.

=head1 Functions

=head2 new

Default constructor created by Class::Std. The named parameter
EXTERNAL should be set to 1 if the API is used from an external
source (e.g. within a service). If EXTERNAL is set, in addition to
the parameter checks, ACL checks are enabled.

=head2 AUTOMETHOD

This method is used by Class::Std when a method is called that is undefined
in the current class. In our case, this method does the parameter
checking for the requested method. If the class has been instantiated
with the EXTERNAL parameter, ACL checks are done in addition. Then the
class name is constructed from the $method_info hash reference and
the corresponding method is called with the given parameters.
