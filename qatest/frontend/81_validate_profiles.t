#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;
use MIME::Base64;
use Crypt::X509;

use Test::More;

package main;

my $result;
my $client = TestCGI::factory();

-d "samples" || die "Please put your certificate samples into the samples/ directory";

# create temp dir
-d "tmp/" || mkdir "tmp/";

sub run_test {

    my $file = shift;

    diag($file);

    my $profile;
    my $style = '00_basic_style';
    if ($file =~ /(\w+)\.((\w+)\.)?crt$/) {
        $profile = $1;
        $style = $3 if ($3);
    } else {
        return;
    }

    my $fh;
    open ($fh, '<', $file);
    if (!$fh) {
        ok(0, 'Opening file '.$file);
        return;
    }

    my $cert = '';
    while (my $row = <$fh>) {
        $cert .= $row;
    }
    close $fh;

    if($cert !~ m{-----BEGIN[^-]*CERTIFICATE-----(.+)-----END[^-]*CERTIFICATE-----}xms) {
        ok(0, 'is pem certificate: ');
        return;
    }
    my $x509 = new Crypt::X509( cert => decode_base64($1) );

    $result = $client->mock_request({
        'page' => 'workflow!index!wf_type!certificate_signing_request_v2',
    });

    is($result->{main}->[0]->{content}->{fields}->[2]->{name}, 'wf_token');

    $result = $client->mock_request({
        'action' => 'workflow!index',
        'wf_token' => undef,
        'cert_profile' => $profile,
        'cert_subject_style' => $style,
    });

    like($result->{goto}, qr/workflow!load!wf_id!\d+/, 'Got redirect');

    my ($wf_id) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;

    diag("Workflow Id is $wf_id");

    $result = $client->mock_request({
        'page' => $result->{goto},
    });

    $result = $client->mock_request({
        'action' => 'workflow!select!wf_action!csr_upload_pkcs10!wf_id!'.$wf_id,
    });

    my $keyname = "tmp/$profile.$style.key";
    my $csrname = "tmp/$profile.$style.csr";
    my $config  = '';

    if ($x509->SubjectAltName) {

        my $typemap = {
            otherName => 'otherName',
            rfc822Name => 'email',
            dNSName => 'DNS',
            x400Address => '', # not supported by openssl
            directoryName => 'dirName',
            ediPartyName => '', # not supported by openssl
            uniformResourceIdentifier => 'URI',
            iPAddress  => 'IP',
            registeredID => 'RID',
        };

        my @san = map {
            my ($type, $value) = split /=/, $_, 2;
            $value =~ s{,}{\\,}g;
            sprintf "%s:%s", $typemap->{$type}, $value;
        } @{$x509->SubjectAltName};

open (my $fh, ">", "tmp/openssl.cnf");
print $fh "[ req ]
default_bits        = 2048
default_keyfile     = privkey.pem
req_extensions = v3_req # The extensions to add to a certificate request
distinguished_name      = req_distinguished_name

[ req_distinguished_name ]
CN=ignore.me

[ v3_req ]
subjectAltName=" . join ",", @san;

        close $fh;
        $config = "-config tmp/openssl.cnf";
    }

    my $subject = `openssl  x509 -noout -subject -in $file`;
    $subject =~ s{subject=\s*}{}g;
    my $pkcs10 = `openssl req -new -nodes $config -subj "$subject" -keyout $keyname | tee $csrname 2>/dev/null`;

    $result = $client->mock_request({
        'action' => 'workflow!index',
        'pkcs10' => $pkcs10,
        'csr_type' => 'pkcs10',
        'wf_token' => undef
    });

    my $ii = 0;
    while (defined $result->{main}->[0]->{content}->{fields}) {

        my $params = { 'action' => 'workflow!index', 'wf_token' => undef };
        map {
            my $key = $_->{name};
            if ($key =~ /^cert_/) {
                if ($_->{value}) {
                    $params->{$key} = $_->{value};
                } elsif (defined $_->{placeholder}) {
                    $params->{$key} = $_->{placeholder} ;
                }
            }
        } @{$result->{main}->[0]->{content}->{fields}};

        $result = $client->mock_request($params);

        # prevent endless loop when something goes wrong
        if ($ii++ > 3) { exit; }
    }

    # this is either submit or the link to enter a policy violation comment
    $result = $client->mock_request({
        'action' => $result->{main}->[0]->{content}->{buttons}->[0]->{action}
    });

    if ($result->{main}->[0]->{content}->{fields} &&
        $result->{main}->[0]->{content}->{fields}->[0]->{name} eq 'policy_comment') {

        $result = $client->mock_request({
            'action' => 'workflow!index',
            'policy_comment' => 'Testing',
            'wf_token' => undef
        });
    };

    $result = $client->mock_request({
        'action' => 'workflow!select!wf_action!csr_approve_csr!wf_id!' . $wf_id,
    });


    is ($result->{status}->{level}, 'success', 'Status is success');

    my $cert_identifier = $result->{main}->[0]->{content}->{data}->[0]->{value}->{label};
    $cert_identifier =~ s/\<br.*$//g;

    # Download the certificate
    $result = $client->mock_request({
         'page' => 'certificate!download!format!pem!identifier!'.$cert_identifier
    });

    open(CERT, ">tmp/$profile.$style.id");
    print CERT $cert_identifier;
    close CERT;

    open(CERT, ">tmp/$profile.$style.crt");
    print CERT $result ;
    close CERT;

    my @errors;
    if ($result !~ m{-----BEGIN[^-]*CERTIFICATE-----(.+)-----END[^-]*CERTIFICATE-----}xms) {
        push @errors, "certificate error";
    } else {
        my $x509new = new Crypt::X509( cert => decode_base64($1) );

        push @errors, "Subject" unless (join(',',@{$x509->Subject}) eq join(',',@{$x509new->Subject}) );

        foreach my $attr (qw(KeyUsage ExtKeyUsage SubjectAltName BasicConstraints)) {
            my $src = $x509->$attr;
            my $new = $x509new->$attr;

            if (defined $new && defined $src) {
                if ( join(',', sort @{$x509->$attr}) ne join(',', sort @{$x509new->$attr})) {
                    push @errors, $attr;
                }
            } elsif (defined $new || defined $src) {
                push @errors, $attr . ' (missing)';
            }
        }

        my %src = $x509->CRLDistributionPoints2;
        my %new = $x509new->CRLDistributionPoints2;
        if (%new && %src) {
            my @srccrl;
            my @newcrl;
            foreach my $key (keys %src) {
                push @srccrl, @{$src{$key}};
            }
            foreach my $key (keys %new) {
                push @newcrl, @{$new{$key}};
            }
            if ( join(',', sort @srccrl) ne join(',', sort @newcrl)) {
                push @errors, 'CDP';
            }
            print Dumper \@newcrl;
        } elsif (%new || %src) {
            push @errors, 'CDP (missing)';
        }

    }

    if (scalar @errors) {
        ok(0, (join ",", @errors));
    } else {
        ok(1, $profile);
    }

}

my @files = <samples/*.crt>;

foreach my $file (@files) {
    run_test $file;
}


done_testing();
