package OpenXPKI::Client::UI::Role::OutputField;
use Moose::Role;

requires qw( log serializer send_command_v2 __persist_response _client );

# Core modules
use DateTime;
use Data::Dumper;

# CPAN modules
use MIME::Base64;

# Project modules
use OpenXPKI::Dumper;
use OpenXPKI::Serialization::Simple;


=head2 render_output_field

Renders a single profile output field, i.e. translates the field definition
from the config into the the specification expected by the web UI.

=cut
sub render_output_field {
    my $self = shift;
    my $field = shift;
    my $custom_handlers = shift // {};
    my $custom_params = shift // {};

    my $name = $field->{name} || '';
    my $type = $field->{type} || '';

    my $item = {
        name => $name,
        value => $field->{value} // '',
        format =>  $field->{format} || ''
    };

    $item->{className} = $field->{uiclass} if $field->{uiclass};

    if ($item->{format} eq 'spacer') {
        return { format => 'head', className => $item->{className} || 'spacer' };
    }

    # Suppress key material, exceptions are vollatile and download fields
    if ($item->{value} =~ /-----BEGIN[^-]*PRIVATE KEY-----/ && $item->{format} ne 'download' && substr($name,0,1) ne '_') {
        $item->{value} = 'I18N_OPENXPKI_UI_WORKFLOW_SENSITIVE_CONTENT_REMOVED_FROM_CONTEXT';
    }

    # Label, Description, Tooltip
    foreach my $prop (qw(label description tooltip preamble)) {
        $item->{$prop} = $field->{$prop} if $field->{$prop};
    }
    $item->{label} ||= $name;


    # we have several formats that might have non-scalar values
    if (OpenXPKI::Serialization::Simple::is_serialized( $item->{value} ) ) {
        $item->{value} = $self->serializer->deserialize( $item->{value} );
    }

    # auto-assign format based on some assumptions if no format is set
    if (!$item->{format}) {

        # create a link on cert_identifier fields
        if ( $name =~ m{ cert_identifier \z }x ||
            $type eq 'cert_identifier') {
            $item->{format} = 'cert_identifier';
        }

        # Code format any PEM blocks
        if (( $name =~ m{ \A (pkcs10|pkcs7) \z }x ) ||
            ( ref $item->{value} eq '' &&
                $item->{value} =~ m{ \A \s* -----BEGIN([A-Z ]+)-----.*-----END([A-Z ]+)---- }xms)) {
            $item->{format} = 'code';
            $item->{value} =~ s{(\A\s*|\s*\z)}{}sg;
        } elsif ($type eq 'textarea') {
            $item->{format} = 'nl2br';
        }

        if (ref $item->{value}) {
            if (ref $item->{value} eq 'HASH') {
                $item->{format} = 'deflist';
            } elsif (ref $item->{value} eq 'ARRAY') {
                $item->{format} = 'ullist';
            }
        }
        ##! 64: 'Auto applied format: ' . $item->{format}
    }

    my %handlers = (
        "cert_identifier" => \&__render_cert_identifier,
        "workflow_id" => \&__render_workflow_id,
        "download" => \&__render_download,
        "itemcnt" => \&__render_itemcnt,
        "deflist" => \&__render_deflist,
        "grid" => \&__render_grid,
        "chart" => \&__render_chart,
        $custom_handlers->%*,
    );
    my $match;
    foreach my $test (keys %handlers) {
        next unless $item->{format} eq $test;
        my $code = $handlers{$test}->($self, $field, $item, $custom_params);
        return if ($code || 0) == -1;
        $match = 1;
    }

    if (not $match and
        ($type eq 'select' and !$field->{template} and $field->{option} and ref $field->{option} eq 'ARRAY')
    ) {
        foreach my $option (@{$field->{option}}) {
            return unless defined $option->{value};
            if ($item->{value} eq $option->{value}) {
                $item->{value} = $option->{label};
                last;
            }
        }
    }

    if ($field->{template}) {

        $self->log->trace("Render output using template on field '$name', template: ".$field->{template}.', value: ' . Dumper $item->{value}) if $self->log->is_trace;

        # Rendering target depends on value format
        # deflist: iterate over each label/value pair and render the value template
        if ($item->{format} eq "deflist") {
            $item->{value} = [
                map {
                    my $val = $self->send_command_v2('render_template', { template => $field->{template}, params => $_ });
                    {
                        # $_ is a HashRef: { label => STR, key => STR, value => STR } where key is the field name (not needed here)
                        label => $_->{label},
                        value => [ split (/\|/, $val) ],
                        format => 'raw',
                    }
                }
                @{ $item->{value} }
            ];

        # bullet list, put the full list to tt and split at the | as sep (as used in profile)
        } elsif ($item->{format} eq "ullist" || $item->{format} eq "rawlist") {
            my $out = $self->send_command_v2('render_template', {
                template => $field->{template},
                params => { value => $item->{value} },
            });
            $self->log->debug('Rendered template: ' . $out);
            if ($out) {
                my @val = split /\s*\|\s*/, $out;
                $self->log->trace('Split ' . Dumper \@val) if $self->log->is_trace;
                $item->{value} = \@val;
            } else {
                $item->{value} = undef; # prevent pushing emtpy lists
            }

        } elsif (ref $item->{value} eq 'HASH' && $item->{value}->{label}) {
            $item->{value}->{label} = $self->send_command_v2('render_template', {
                template => $field->{template},
                params => { value => $item->{value}->{label} },
            });

        } else {
            $item->{value} = $self->send_command_v2('render_template', {
                template => $field->{template},
                params => { value => $item->{value} },
            });
        }

    } elsif ($field->{yaml_template}) {
        ##! 64: 'Rendering value: ' . $item->{value}
        $self->log->trace('Template value: ' . SDumper $item ) if $self->log->is_trace;
        my $structure = $self->send_command_v2('render_yaml_template', {
            template => $field->{yaml_template},
            params => { value => $item->{value} },
        });
        $self->log->trace('Rendered YAML template: ' . SDumper $structure) if $self->log->is_trace;
        ##! 64: 'Rendered YAML template: ' . $out
        if (defined $structure) {
            $item->{value} = $structure;
        } else {
            $item->{value} = undef; # prevent pushing emtpy lists
        }
    }

    return $item;
}

# convert format cert_identifier into a link
sub __render_cert_identifier {
    my ($self, $field, $item) = @_;

    $item->{format} = 'link';
    return unless $item->{value}; # do not create if the field is empty
    my $label = $item->{value};

    my $id = $item->{value};
    $item->{value}  = {
        label => $label,
        page => "certificate!detail!identifier!${id}",
        target => 'popup',
        # label is usually formated to a human readable string
        # but we sometimes need the raw value in the UI for extras
        value => $id,
    };

    return 1;
}

# link to another workflow - performs ACL check
sub __render_workflow_id {
    my ($self, $field, $item) = @_;

    my $workflow_id = $item->{value};
    return -1 unless $workflow_id; # do not output this field unless there is a workflow ID

    my $can_access = $self->send_command_v2(check_workflow_acl => { id => $workflow_id  });
    if ($can_access) {
        $item->{format} = 'link';
        $item->{value}  = {
            label => $workflow_id,
            page => 'workflow!load!wf_id!'.$workflow_id,
            target => 'top',
            value => $workflow_id,
        };
    } else {
        $item->{format} = '';
    }

    return 1;
}

# create a link to download the given filename
sub __render_download {
    my ($self, $field, $item) = @_;

    my $mime = 'application/octect-stream';
    $item->{format} = 'download';

    return -1 unless $item->{value}; # do not output this field if there is no value

    # parameters given in the field definition
    my $param = $field->{param} || {};

    # Arguments for the UI field
    # label => STR           # text above the download field
    # type => "plain" | "base64" | "link",  # optional, default: "plain"
    # data => STR,           # plain data, Base64 data or URL
    # mimetype => STR,       # optional: mimetype passed to browser
    # filename => STR,       # optional: filename, default: depends on data
    # autodownload => BOOL,  # optional: set to 1 to auto-start download
    # hide => BOOL,          # optional: set to 1 to hide input and buttons (requires autodownload)

    my $vv = $item->{value};
    # scalar value
    if (!ref $vv) {
        # if an explicit filename is set, we assume it is v3.10 or
        # later so we assume the value is the data and config is in
        # the field parameters
        if ($param->{filename}) {
            $vv = { filename => $param->{filename}, data => $vv };
        } else {
            $vv = { filename => $vv, source => 'file:'.$vv };
        }
    }

    # very old legacy format where file was given without source
    if ($vv->{file}) {
        $vv->{source} = "file:".$vv->{file};
        $vv->{filename} = $vv->{file} unless($vv->{filename});
        delete $vv->{file};
    }

    # merge items from field param
    map { $vv->{$_} ||= $param->{$_}  } ('mime','label','binary','hide','auto','filename');

    # guess filename from a file source
    if (!$vv->{filename} && $vv->{source} && $vv->{source} =~ m{ file:.*?([^\/]+(\.\w+)?) \z }xms) {
        $vv->{filename} = $1;
    }

    # set mime to default / from format
    $vv->{mime} ||= $mime;

    # we have an external source so we need a link
    if ($vv->{source}) {
         my $target = $self->__persist_response({
            source => $vv->{source},
            attachment =>  $vv->{filename},
            mime => $vv->{mime}
        });
        $item->{value}  = {
            label => 'I18N_OPENXPKI_UI_CLICK_TO_DOWNLOAD',
            type => 'link',
            filename => $vv->{filename},
            data => $self->_client->script_url . "?page=$target",
        };
    } else {
        my $type;
        # payload is binary, so encode it and set type to base64
        if ($vv->{binary}) {
            $type = 'base64';
            $vv->{data} = encode_base64($vv->{data}, '');
        } elsif ($vv->{base64}) {
            $type = 'base64';
        }
        $item->{value}  = {
            label=> $vv->{label},
            mimetype => $vv->{mime},
            filename => $vv->{filename},
            type => $type,
            data => $vv->{data},
        };
    }

    if ($vv->{hide}) {
        $item->{value}->{autodownload} = 1;
        $item->{value}->{hide} = 1;
    } elsif ($vv->{auto}) {
        $item->{value}->{autodownload} = 1;
    }

    return 1;
}

sub __render_itemcnt {
    my ($self, $field, $item) = @_;

    my $list = $item->{value};

    if (ref $list eq 'ARRAY') {
        $item->{value} = scalar @{$list};
    } elsif (ref $list eq 'HASH') {
        $item->{value} = scalar keys %{$list};
    } else {
        $item->{value} = '??';
    }
    $item->{format} = '';

    return 1;
}

sub __render_deflist {
    my ($self, $field, $item) = @_;

    # sort by label
    my @val;
    if ($item->{value} && (ref $item->{value} eq 'HASH')) {
        @val = map { { label => $_, value => $item->{value}->{$_}} } sort keys %{$item->{value}};
        $item->{value} = \@val;
    }

    return 1;
}

sub __render_grid {
    my ($self, $field, $item) = @_;
    my @head;
    # item value can be data or grid specification
    if (ref $item->{value} eq 'HASH') {
        my $hv = $item->{value};
        $item->{header} = [ map { { 'sTitle' => $_ } } @{$hv->{header}} ];
        $item->{value} = $hv->{value};
    } elsif ($field->{header}) {
        $item->{header} = [ @head = map { { 'sTitle' => $_ } } @{$field->{header}} ];
    } else {
        $item->{header} = [ @head = map { { 'sTitle' => '' } } @{$item->{value}->[0]} ];
    }
    $item->{action} = $field->{action};
    $item->{target} = $field->{target} ? $field->{target} : 'top';

    return 1;
}

sub __render_chart {
    my ($self, $field, $item) = @_;
    my @head;

    my $param = $field->{param} || {};

    $item->{options} = { type => 'line' };

    # read options from the fields param method
    foreach my $key ('width','height','type','title') {
        $item->{options}->{$key} = $param->{$key} if (defined $param->{$key});
    }

    # series can be a hash based on the datas keys or an array
    my $series = $param->{series};
    $item->{options}->{series} = $series if (ref $series eq 'ARRAY');

    my $start_at = 0;
    my $interval = 'months';

    # item value can be data (array) or chart specification (hash)
    if (ref $item->{value} eq 'HASH') {
        # single data row chart with keys as groups
        my $hv = $item->{value};
        my @series;
        my @keys;
        if (ref $series eq 'HASH') {
            # series contains label as key / value hash
            @keys = sort keys %{$series};
            map {
                # series value can be a scalar (label) or a full hash
                my $ll = $series->{$_};
                push @series, (ref $ll ? $ll : { label => $ll });
                $_;
            } @keys;

        } elsif (ref $series eq 'ARRAY') {
            @keys = map {
                my $kk = $_->{key};
                delete $_->{key};
                $kk;
            } @{$series};

        } else {

            @keys = grep { ref $hv->{$_} ne 'HASH' } sort keys %{$hv};
            if (my $prefix = $param->{label}) {
                # label is a prefix to be merged with the key names
                @series = map { { label => $prefix.'_'.uc($_) } } @keys;
            } else {
                @series = map {  { label => $_ } } @keys;
            }
        }

        # check if we have a single row or multiple, we also assume
        # that all keys have the same value count so we just take the
        # first one
        if (ref $hv->{$keys[0]}) {
            # get the number of items per row
            my $ic = scalar @{$hv->{$keys[0]}};

            # if start_at is not set, we do a backward calculation
            $start_at ||= DateTime->now->subtract ( $interval => ($ic-1) );
            my $val = [];
            for (my $drw = 0; $drw < $ic; $drw++) {
                my @row = (undef) x @keys;
                unshift @row, $start_at->epoch();
                $start_at->add( $interval => 1 );
                $val->[$drw] = \@row;
                for (my $idx = 0; $idx < @keys; $idx++) {
                    $val->[$drw]->[$idx+1] = $hv->{$keys[$idx]}->[$drw];
                }
            }
            $item->{value} = $val;

        } elsif ($item->{options}->{type} eq 'pie') {

            my $sum = 0;
            my @val = map { $sum+=$hv->{$_}; $hv->{$_} || 0 } @keys;
            if ($sum) {
                my $divider = 100 / $sum;

                @val = map {  $_ * $divider } @val;

                unshift @val, '';
                $item->{value} = [ \@val ];
            }

        } else {
            # only one row so this is easy
            my @val = map { $hv->{$_} || 0 } @keys;
            unshift @val, '';
            $item->{value} = [ \@val ];
        }
        $item->{options}->{series} = \@series if (@series);

    } elsif (ref $item->{value} eq 'ARRAY' && @{$item->{value}}) {
        if (!ref $item->{value}->[0]) {
            $item->{value} = [ $item->{value} ];
        }
    }

    return 1;
}

1;
