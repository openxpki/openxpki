
use strict;
use warnings;

## configure test environment

my $base = 't/instance';
our %config = (
    server_dir         => $base,
    config_dir         => "$base/etc/openxpki",
    var_dir            => "$base/var/openxpki",
    config_file        => "$base/etc/openxpki/config.xml",
    socket_file        => "/var/tmp/openxpki-client-test.socket",
    debug              => 0,
);
if ($ENV{DEBUG}) {
    $config{debug} = 1;
}

our $PWD      = `pwd`;
    $PWD      =~ s/\n//g;
our $INSTANCE = "$PWD/t/tc1";
our $CONFIG   = "openxpki.conf";
our $OUTPUT   = "t/html_output";

$INSTANCE   = $ENV{INSTANCE}   if (exists $ENV{INSTANCE});    

$ENV{DOCUMENT_ROOT}        = "$PWD/htdocs"; ## comp_path
$ENV{OPENXPKI_SOCKET_FILE} = "$PWD/t/tc1/var/openxpki/openxpki.socket";

## this is for the caching itself
use XML::Simple;
use XML::Parser;
$XML::Simple::PREFERRED_PARSER = "XML::Parser";

our $XS = XML::Simple->new (ForceArray    => 1,
                            ForceContent  => 1,
                            SuppressEmpty => undef,
                            KeyAttr       => [],
                            KeepRoot      => 1);

sub check_html
{
    my $keys  = shift;
    my $path  = $keys->{PATH};
    my $page  = $keys->{PAGE};

    my @list = split "\/", $path;
    my @path = ();
    foreach my $item (@list)
    {
        push @path, [ split ":", $item ];
    }
    my $count = 1;
    foreach my $item (@path)
    {
        return  $count if (not exists $page->{$item->[0]});
        $page = $page->{$item->[0]};
        if (defined $item->[1])
        {
            return -$count if (not exists $page->[$item->[1]]);
            $page = $page->[$item->[1]];
        }
        $count++;
    }
    if (exists $keys->{VALUE})
    {
        return $count if (ref $page);
        return -$count if ($keys->{VALUE} ne $page);
    }
    if (exists $keys->{REGEX})
    {
        return $count if (ref $page);
        return -$count if ($page !~ /^.*$keys->{REGEX}.*$/);
    }
    return 0;
}

sub check_session_id
{
    my $page = shift;
    return 1 if (not exists $page->{html}->[0]->{body}->[0]->{div}->[0]->{div}->[1]->{form}->[0]->{input}->[0]);
    $page = $page->{html}->[0]->{body}->[0]->{div}->[0]->{div}->[1]->{form}->[0]->{input}->[0];
    return 2 if ($page->{type} ne "hidden");
    return 3 if ($page->{name} ne "__session_id");
    return 4 if (length $page->{value} < 16);
    return 0;
}

sub get_session_id
{
    my $page = shift;
    return undef if (0 != check_session_id($page));
    return $page->{html}->[0]->{body}->[0]->{div}->[0]->{div}->[1]->{form}->[0]->{input}->[0]->{value};
}

sub dump_page
{
    my $page = shift;
    use Data::Dumper;
    print STDERR Dumper($page);
}

sub write_html
{
    my $keys     = shift;
    my $filename = $keys->{FILENAME};
    my $data     = $keys->{DATA};

    ## strip off http header
    $data =~ s/^.*\r\n\r\n//s;

    return 1 if (not open FD, ">$OUTPUT/$filename");
    return 2 if (not print FD $data);
    return 3 if (not close FD);
    return 0;
}

sub get_parsed_xml
{
    my $filename = shift;
    return $XS->XMLin ("$OUTPUT/$filename");
}

1;
