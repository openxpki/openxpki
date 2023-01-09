package OpenXPKI::Server::Workflow::Activity::Reports::Detail;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::DateTime;
use OpenXPKI::Template;
use DateTime;
use Workflow::Exception qw(configuration_error);
use JSON;

sub execute {

    my $self = shift;
    my $workflow = shift;

    my $context = $workflow->context();
    my $pki_realm = CTX('session')->data->pki_realm;

    # write report to the context - WARNING: might eat up some memory
    my $target_key = $self->param('target_key');

    my $target_name;
    my $fh;
    my $buffer;


    my $valid_at;
    if ($self->param('valid_at')) {
       $valid_at = OpenXPKI::DateTime::get_validity({
            VALIDITY =>  $self->param('valid_at'),
            VALIDITYFORMAT => 'detect',
        });
    } else {
       $valid_at = DateTime->now();
    }

    my $epoch = $valid_at->epoch();

    my %where = (
        'certificate.req_key' => { '!=' => undef },
        'certificate.pki_realm' => $pki_realm,
    );

    my $p = {
        cutoff_notbefore => 0,
        cutoff_notafter => 0,
        include_revoked => 0,
        include_expired => 0,
        unique_subject => 0,
        profile => '',
        subject => '',
        delimiter => '|',
        format => 'csv',
        aggregate => '',
        tenant => ($workflow->attrib('tenant') || ''),
        head => 'Full Certificate Report, Realm [% pki_realm %], Validity Date: [% valid_at %], Export Date: [% export_date %][% IF report_config %], Report Config [% report_config %][% END %]',
    };

    # define general setting parameters
    my @param = keys %{$p};
    my $query_attr;

    foreach my $key ($self->param()) {
        # we are not interessted in undef parameters
        next unless defined $self->param($key);
        ##! 64: $key
        # keys for supported attributes
        if ($key =~ /\A(meta_|system_|subject_alt_name\z)/) {
            ##! 32: 'Add as attribute ' . $key
            $query_attr->{$key} = $self->param($key);

            $query_attr->{$key} = undef
                if (ref $query_attr->{$key} eq '' && $query_attr->{$key} eq '<undef>');
            next;
        }
        # general setting parameters
        next unless (grep { $key eq $_ } @param);
        ##! 32: 'Add as param ' . $key
        $p->{$key} = $self->param($key);
    }


    # Additional columns and override to the above configs
    my $report_config = $self->param('report_config');
    my @columns;
    my @head;
    my $tt = OpenXPKI::Template->new();
    if ($report_config) {
        my $config = CTX('config');
        ##! 16: 'Loading config ' . $report_config
        # override selector config
        foreach my $key ($config->get_keys(['report', $report_config ])) {
            ##! 64: $key
            if ($key =~ /\A(meta_|system_|subject_alt_name)/) {
                ##! 32: 'Add as attribute ' . $key
                my @val = $config->get_scalar_as_list(['report', $report_config, $key]);
                if (scalar @val > 1) {
                    $query_attr->{$key} = [ @val ];
                } elsif ($val[0] eq '<undef>') {
                    $query_attr->{$key} = undef;
                } elsif ($val[0] =~ m{[%\?]}) {
                    $query_attr->{$key} = { '-like' => $val[0] };
                } else {
                    $query_attr->{$key} = $val[0];
                }
                next;
            }
            # general setting parameters
            next unless (grep { $key eq $_ } @param);

            # profile and subject can be a list
            if ($key eq 'profile' || $key eq 'subject') {
                $p->{$key} = [ $config->get_scalar_as_list(['report', $report_config, $key]) ];
            } else {
                $p->{$key} = $config->get(['report', $report_config, $key]);
            }
        }
        @columns = $config->get_list(['report', $report_config, 'cols']);
        @head = map { $_->{head} // '' } @columns;
    }

    ##! 16: 'Params ' . Dumper $p
    ##! 16: 'Query Attributes ' . Dumper $query_attr
    configuration_error('Invalid value for aggregate parameter') unless(!$p->{aggregate} || $p->{aggregate} eq 'count');

    # If include_revoke it not set, we filter on ISSUED status
    if (!$p->{include_revoked}) {
        $where{'status'} = 'ISSUED';
    }

    # if cutoff is set, we filter on notbefore between valid_at and cutoff
    if ($p->{cutoff_notbefore}) {
        my $cutoff = OpenXPKI::DateTime::get_validity({
            REFERENCEDATE => $valid_at,
            VALIDITY => $p->{cutoff_notbefore},
            VALIDITYFORMAT => 'detect',
        })->epoch();

        $where{'notbefore'} = ($epoch > $cutoff)
            ? { -between => [ $cutoff, $epoch  ] }
            : { -between => [ $epoch, $cutoff  ] };
    } else {
        $where{'notbefore'} = { '<=', $epoch };
    }


    my $expiry_cutoff = $epoch;
    # if expired certs should be included, we just move the notafter limit
    if ($p->{include_expired}) {
        $expiry_cutoff = OpenXPKI::DateTime::get_validity({
            REFERENCEDATE => $valid_at,
            VALIDITY => $p->{include_expired},
            VALIDITYFORMAT => 'detect',
        })->epoch();
    }

    # if notafter cutoff is set, we use it as upper limit
    # we always expect this to be a positive offset
    if ($p->{cutoff_notafter}) {
        my $cutoff = OpenXPKI::DateTime::get_validity({
            REFERENCEDATE => $valid_at,
            VALIDITY => $p->{cutoff_notafter},
            VALIDITYFORMAT => 'detect',
        })->epoch();
        $where{'notafter'} = { -between => [ $expiry_cutoff, $cutoff  ] };
    } else {
        $where{'notafter'} = { '>=', $expiry_cutoff };
    }

    # Allow pattern search with *Subject* and %Subject%
    if ($p->{subject}) {
        my $subject = ref $p->{subject} ? $p->{subject} : [ $p->{subject} ];
        @$subject = map { s/\*/%/g; $_ } @$subject;
        $where{'certificate.subject'} = { 'like' => $subject };
    }

    my $need_csr = 0;
    my $need_attr = 0;
    my @attr;

    # csr field requested in column list
    if (grep { $_->{csr} } @columns) {
        $need_csr = 1;
    }

    if ($p->{profile}) {
        my $profile = ref $p->{profile} ? $p->{profile} : [ $p->{profile} ];
        $where{'csr.profile'} = $profile;
        $need_csr = 1;
    }

    foreach my $col (@columns) {
        # If templating is active, we load all attributes
        if ($col->{template} && $col->{template} =~ m{attribute}) { $need_attr = 1; last; }
        # List all atrributes that are required for joined loading
        if ($col->{attribute}) { push @attr, $col->{attribute}; }
    }

    my $sth;
    my $cols = [
        'certificate.subject',
        'certificate.cert_key',
        'certificate.req_key',
        'certificate.identifier',
        'certificate.status',
        'certificate.notafter',
        'certificate.notbefore',
        'certificate.issuer_dn',
        'certificate.identifier',
        'certificate.subject_key_identifier',
        'certificate.authority_key_identifier'
    ];
    my @header = ("request id", "subject", "serial", "identifier", "notbefore", "notafter", "status", "issuer");

    my $join = '';
    my @groupby;
    # join csr table for profile
    if ($need_csr) {
        $join = ' {req_key=req_key,pki_realm=pki_realm} csr ';
        push @{$cols}, 'csr.profile';
    }

    # If single attributes are requested, create extra joins
    if (!$need_attr && @attr) {
        my $ii=0;
        # if aggregate is on we reset the columns list
        if ($p->{aggregate}) {
            $cols = [];
            @header = ();
        }
        foreach my $aa (@attr) {
            $ii++;
            $join .= " =>certificate.identifier=ca${ii}.identifier,ca${ii}.attribute_contentkey='$aa' certificate_attributes|ca${ii} ";
            push @{$cols}, "ca${ii}.attribute_value as $aa";
            push @groupby, $aa if ($p->{aggregate});

            if (exists $query_attr->{$aa}) {
                $where{"ca${ii}.attribute_value"} = $query_attr->{$aa};
                delete $query_attr->{$aa};
            }

        }
    }

    # attribute based query filters, to be added as joins if they do not already exists
    my $ii=0;
    foreach my $key (keys %{$query_attr}) {
        ##! 16: 'Checking key ' . $key
        $ii++;
        $join .= " =>certificate.identifier=cas${ii}.identifier,cas${ii}.attribute_contentkey='$key' certificate_attributes|cas${ii} ";
        $where{"cas${ii}.attribute_value"} = $query_attr->{$key};
    }

    ##! 32: $join
    ##! 32: $cols
    ##! 32: \%where
    if (@groupby) {
        push @{$cols}, 'count(*) as amount';
        push @head, '';
        $sth = CTX('dbi')->select(
            ($join ? (from_join => 'certificate '.$join) : (from => 'certificate')),
            columns  => $cols,
            where => \%where,
            group_by => \@groupby,
            order_by => \@groupby
        );

    } elsif ($join) {
        $sth = CTX('dbi')->select(
            from_join => 'certificate '.$join,
            order_by => [ '-notbefore', '-req_key' ],
            columns  => $cols,
            where => \%where,
            ($query_attr ? (distinct => 1) : ()),
        );
    } else {
        $sth = CTX('dbi')->select(
            from => 'certificate',
            order_by => [ '-notbefore', '-req_key' ],
            columns  => $cols,
            where => \%where,
            ($query_attr ? (distinct => 1) : ()),
        );
    }

    my $delim = $p->{delimiter} || '|';

    my $head = $tt->render($p->{head}, {
        pki_realm => $pki_realm,
        valid_at => $valid_at->iso8601(),
        export_date => DateTime->now()->iso8601,
        report_config => $report_config
    });

    if ($p->{format} eq 'memory') {
        $buffer = {};
        $target_key ||= '_report_data';

    } elsif ($target_key) {

        # create a in memory file handle
        open( $fh, '>:encoding(UTF-8)', \$buffer) or die "Can't open memory file: $!\n";

    } else {
        # Setup for write to disk
        $target_name = $self->param('target_filename');
        my $target_dir = $self->param('target_dir');
        my $umask = $self->param( 'target_umask' ) || "0640";

        if (!$target_name) {
            $fh = File::Temp->new( UNLINK => 0, DIR => $target_dir );
            $target_name = $fh->filename;
        } else {

            # relative path, prefix with directory
            if ($target_name !~ m{ \A \/ }xms) {
                if (!$target_dir) {
                    configuration_error('Full path for target_name or target_dir is required!');
                }

                $target_name = $target_dir.'/'.$target_name;
            }

            if (-e $target_name) {

                if ($self->param('target_overwrite')) {
                    unlink($target_name);
                } else {
                    OpenXPKI::Exception->throw(
                        message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_REPORTS_TARGET_FILE_EXISTS',
                        params => { FILENAME => $target_name }
                    );
                }
            }

            open $fh, ">:encoding(UTF-8)", $target_name;
        }

        if (!$fh || !$target_name) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_REPORTS_UNABLE_TO_WRITE_REPORT_FILE',
                params => { FILENAME => $target_name, DIRNAME => $target_dir }
            );
        }

        chmod oct($umask), $target_name;
    }

    my $json;
    if (!$fh) { # target memory, receives only the data!

        $buffer = {
            header => [@header, @head],
            value => [],
        };
        $buffer->{title} = $head if ($head);

    } elsif ($p->{format} eq 'json') {

        $json = JSON->new();
        if ($head) {
            my $bb = $json->encode({ title => $head });
            chop($bb); # replace the closing bracket with a comma
            print $fh "$bb,";
        } else {
            print $fh "{";
        }
        my $bb = $json->encode([@header, @head]);
        print $fh '"header":'.$bb.'],{"data":[';

    } else {
        if ($head) { print $fh $head."\n"; }
        print $fh join($delim, @header, @head)."\n";
    }

    my $subject_seen = {};
    my $cnt;
    while (my $item = $sth->fetchrow_hashref) {

        ##! 64: 'Item ' . Dumper $item

        if ($p->{unique_subject}) {
            my $subject = lc($item->{subject});
            next if ($subject_seen ->{ $subject });
            $subject_seen ->{ $subject } = 1;
        }


        $cnt++;
        my @line;
        # default header is on, add default items
        if (@header) {
            my $serial = unpack('H*', Math::BigInt->new( $item->{cert_key})->to_bytes );

            my $status = $item->{status};
            if ($status eq 'ISSUED' && $item->{notafter} < $epoch) {
                $status = 'EXPIRED';
            }
            @line = (
                $item->{req_key},
                $item->{subject},
                $serial,
                $item->{identifier},
                DateTime->from_epoch( epoch => $item->{notbefore} )->iso8601(),
                DateTime->from_epoch( epoch => $item->{notafter} )->iso8601(),
                $status,
                $item->{issuer_dn}
            );
        }

        my $attrib;
        if ($need_attr) {
            $attrib = CTX('api2')->get_cert_attributes(
                identifier => $item->{identifier},
                tenant => $p->{tenant},
            );
        } elsif(@attr) {
            foreach my $aa (@attr) {
                # mock result of get_cert_attributes
                $attrib->{$aa} = [ $item->{$aa} // '' ];
            }
        }

        # add extra columns
        if (@columns) {
            foreach my $col (@columns) {
                # FIXME Report customization will most likely not work anymore
                if ($col->{template}) {
                    push @line, $tt->render( $col->{template}, { attribute => $attrib, cert => $item } );
                }
                elsif ($col->{cert}) {
                    push @line, $item->{ lc($col->{cert}) };
                }
                elsif ($col->{csr}) {
                    push @line, $item->{ lc($col->{csr}) };
                }
                elsif ($col->{attribute} && ref $attrib->{ $col->{attribute} } eq 'ARRAY') {
                    push @line, $attrib->{ $col->{attribute} }->[0];
                }
                else {
                    push @line, '';
                }
            }
        }
        if (@groupby) {
            push @line, $item->{amount}
        }

        if (!$fh) {
            push @{$buffer->{value}}, \@line;
        } elsif ($json) {
            print $fh "," if ($cnt > 1);
            print $fh $json->encode(\@line);
        } else {
            print $fh join($delim, @line) . "\n";
        }
    }


    # close json structure
    print $fh "]}" if ($json);

    # close file handle
    close $fh if ($fh);

    $context->param('total_count', $cnt);

    if ($target_key) {
        $context->param( $target_key => $buffer );
    }
    else {
        $context->param('report_filename' =>  $target_name );
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Reports::Detail

=head1 Description

Write a detailed report with certificate status information in CSV format.
Data can be written to a file or into the workflow context. If you have a
large report make sure your database settings can handle the report size!
It might also be wise to either use a volatile context item or clean up
after you are done to free the database space.

Selection criteria and output format can be controlled by several activity
parameters, the default is to print all currenty valid certificates.

=head1 Configuration

=head2 Activity parameters

=over

=item format

Default is I<csv> using I<delimiter> to create lines. If set to I<json>,
the result is encoded using JSON with the keys I<title>, I<head> and
I<data>. Set to I<memory> to retrieve the data portion of the report
directly in the context value defined by I<target_key>.

=item target_key

Write the report data into the workflow context using this key. The
filesystem is not used in this case, so all file related settings are
ignored.

If the format is set to I<memory> the default value is _report_data.

=item target_filename

Filename to write the report to, if relative (no slash), target_dir must
be set and will be prepended. If not given, a random filename is set.

=item target_dir

Mandatory if target_filename is relative or not set.

=item target_overwrite

boolean, overwrite the target file if it exists.

=item target_umask

The umask to set on the generated file, default is 640. Note that the
owner is the user/group running the socket, if you want to download
this file using the webserver, make sure that either the webserver has
permissions on the daemons group or set the umask to 644.

=item delimiter

A single char which is used as delimiter. Default is the pipe symbol |. Be
aware that no escaping or quoting of values is done, so you can only use a
symbol that will not occur in the data fields! Good choices beside the pipe
is a tab (\t), semicolon (;) or hash (#);

=item head

A string or template toolkit pattern to put into the first line of the report
file. If not set, a default header is added. Available template vars are
(both dates are in ISO8601 format):

=over

=item export_date

=item valid_at

=item pki_realm

=item report_config

=back

=item include_expired

Parseable OpenXPKI::Datetime value (autodetected), certificates which are
expired after the given date are included in the report. Default is not to
include expired certificates.

=item include_revoked

If set to a true value, certificates which are not in ISSUED state
(revoked, crl pending, on hold) are also included in the report. Default
is to show only issued certificates.

=item valid_at

Parseable OpenXPKI::Datetime value (autodetected) used as base for validity
calculation. Default is now.

=item cutoff_notbefore

Parseable OpenXPKI::Datetime value (autodetected), show only certificates
where notebefore is between valid_at and this value.

=item cutoff_notafter

Parseable OpenXPKI::Datetime value (autodetected), show certificates where
notafter is less then value. The requested valid_at or, if set, the expiry
cutoff date is added as lower border.

=item unique_subject

If set to a true value, only the certiticate with the latest notbefore date
for each subject is included in the report. Note that filtering on subject
is done AFTER the other filters, e.g. in case you do not include revoked
certifiates you get the latest one that was not revoked. Subjects are
compared case insensitive!

=item aggregate

Pass the name of a column you want to aggregate the result on. This will
turn off the default columns and append the rowcount per line as the last
column.

=item subject

Expression to use as filter on the I<subject> of the certificate. This
is passed with a "like" operator to the sql layer, the asterisk can be
used as wildcard. Mutiple expressions are possible and or'ed together.

=item profile

Only include certificates with this profile in the report, mutliple
profiles can be passed as list.

=item subject_alt_name

Filter certificates having a certain subject_alt_name set, can be a
scalar with SQL wildcards OR a list of items.

=item meta_*, system_*

Lets you search for any certificate attribute having a listed prefix.
You can set the special value I<<undef>> (including the angle brackets)
to search for rows without a certain attribute.

=item report_config

Lookup extended specifications in the config system at report.<report_config>.

=back

=head2 Report Config

The config can contain any of the filter controls which will override any
given value from the activity if a value is given.

Additional columns can also be specified, these are appended at the end
of each line.

   cols:
     - head: Title put in the head columns
       cert: issuer_identifier
     - head: Just another title
       attribute: meta_email
     - head: Third column
       template: "[% attribute.meta_email %]"
     - head: The profile given in the CSR
       csr: profile

Each column definition should have a value for I<head> that is printed
in the reprt header to identify this column. Each column must have
exactly one of the following keys that describes the content to display.

=head3 cert

Show the value of the named column from the certificate table.
Available columns are:

=over

=item subject

=item certificate_serial

=item csr_serial

=item identifier

=item status

=item notafter

=item notbefore

=item issuer_dn

=item issuer_identifier

=item subject_key_identifier

=item authority_key_identifier

=back

=head2 csr

Show the value of the named column from the csr table, the only valid
name is I<profile>.

=head2 attribute

Show the value of the given attribute from the certificate_attributes
table. If the given attribute is multivalued, the behaviour depends on
the remaining report spec. If you have any other column that is using
a template to render an attribute, you will see a single line with a
random pick from the list of attributes. If you do not have such a
column, you will get multiple lines for the same certificate, one for
each value of the attribute.

=head2 template

The string is rendered with OpenXPKI::Template, the input paramaters
are the columns of the cert as defined above in the key I<cert> and
all attributes as returned from get_cert_attributes API call as
hash in the I<attribute> key. Note that all attributes are lists,
even if there are single valued!

=head2 Full example

Your activity definition:

    generate_report:
        class: OpenXPKI::Server::Workflow::Activity::Reports::Detail
        param:
            target_umask: 0644
            _map_target_filename: "expiry report [% USE date(format='%Y-%m-%dT%H:%M:%S') %][% date.format( context.valid_at ) %].csv"
            target_dir: /tmp
            report_config: expiry

Content of report/expiry.yaml inside realms config directory:

   cutoff_notafter: +000060
   include_expired: -000030

   cols:
     - head: Requestor eMail
       attribute: meta_email

This gives you a nice report about certificates which have expired within
the last 30 days or will expire in the next 60 days with the contact email
used while the request process.
