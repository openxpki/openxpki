#!/usr/bin/perl
use strict;
use warnings;
use utf8;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp qw/ tempfile /;

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Crypto.*'} = 100;

# Project modules
use OpenXPKI::FileUtils;
use lib "$Bin/../lib";
use OpenXPKI::Test;

plan tests => 11;

#
# Setup env
#
my $oxitest = OpenXPKI::Test->new->setup_env->init_server();

my $passwd = "vcgT7MtIRrZJmWVTgTsO+w";
my $rsa    = "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFHzBJBgkqhkiG9w0BBQ0wPDAbBgkqhkiG9w0BBQwwDgQISNoARhy+9wACAggA\nMB0GCWCGSAFlAwQBKgQQirJStjGiObx5dsFHCJg4sgSCBNAFyOpg4yIXOEpDyr+t\ntz7WARhPVJLziYKPT83W+dQwwjUyBFlPWdbzGsA6CeMf5WoRPhRFBm6MBbxhsRk2\nmas8BgKDddIxMU/M4RaDD62nIpfUHkGsdh97kxzUZElDeORQS9m9y/b6b4BMx+vH\n9Zu6e6unlhZjBSnDiOYfbI4DBySZH+imjQPNXYkn2WwSH2Dh2VyuzdvxWvUlaNeU\nwOWi3iknatyKyE33fnSpA9AmsSwnfPWyQ77kKffkYbFZq337iyckz7GIWaNPVH/r\niJ6rS+60KB2no5mAROQ8ixMKT56rKK8cl4kowMpV7S0+sO4j3RqVePwCUX/qScS5\nP6+YMl326ZWyChzuiuSLbjz95GR0DKXIlMK5JGgq4KNl4LIysU5gn8OBNqXW5Dkr\nQmU5zQllhO3iSwuv+lNBBh7lDj5iWVPIn6O911d8wOJVsME16UKGqVicuz+cDhZB\nQCBtJkZ8m1CgDviDGZoqgoSyQA1BLo4gKNfZqfyFoupJjDtqPvngjCQZtuYwlZ+d\nu/FpsTPhYa9qx23HGKaDPZ95lOkEYfGQ9ClbkzI1cCMLzgUNSgFcSGczpt+EgrqF\nA+lJFToyetO9BpeTIgQyUJiaFm7/9hZEHJNPUH6MXrQDVYjgHgtEn8406Luh2vrd\nk8cUqd6YZADZSUxNElCbmhzyp6YNMYzO6xp/kCXq/MOhvWvtOzTnVq7YgCUgtDry\ngj7WegLI+BUtBxvVSXq6w8lyW4lisVz/KVxgmjHdNMtj5L8g6UJzVnAy/ecpVi91\njVcz8gHxWxvedVjoJBOx21BismVFLadOrU3pMmj33SdjePC7ON9DCZ8KVSHoENym\nYEWoMxCNKM0s74WoK6FCwJBAS5V3qnsvPRXw8bsB2B3Nt2BcM31o2ohPba5n9T/p\nwUkEBq6K7hsceUfMgkZbcGiJbxiipT/lbLpDW3IpaH0//BVJDRXFvwd43nwby0E0\nB0l9md98Hq4fUEZBpIXuaoxSw6cJRh5GI+h4pmbx/PQaSWV63bjZTd9WcGggdy80\nYe873PfOeQ3oFMJyg/Zn2OAFBNVGMmaP7l1fkOYTCOu69yK8+Q6q3KDkRKZU/Pec\nEKvciwXA3Z2p45Q8HHzNUZGpbr27ZCp6gyHLyXLcOePPyS4AExw6Vyu1UWcdaozj\nPg+luu+dlgu+S+2sIfhXgihDWH/iOTcxP/kHdC74Ee+OqflrJ7FZlrvNshEjNvvM\nLxmtDBj98YG5r45k56mOKSDjyLfU+MgjD2Lj1TMFYOY2AuZY6GY+OiXJPDyVc8Bv\nnDPV9+IO3Auq9gNjYEAlUUfw4eJHve3fnSZs3ifAyhELNfds5fhJOTUxhbHB7tip\nZiYIh61WY5wSnTmd2ZZKPZHQa/UL+WgxHF6Jsr8BAXgzC7PAallBNP44/pP9ED/B\nBP3Fce97R6k9pR1Cxegq8NFEm9zM/cwDKhhQrFlZ5rcMOy6qDk8bU2ZkamBtVXFo\nRnGd4qjtS+aCWfz+fjmYz1Pdz+ju6H0jfAjoyHc1WWYbeDM1S7C1XN9D3K2md56A\nm5SydJXOqO+eRjfOBB9m/nneB7sd8LPwaXUB3VOdiKX0LEW8GIprPDmp3C4tEpef\ni9d8OJm/t2KAaBchNlJOauEvBw==\n-----END ENCRYPTED PRIVATE KEY-----\n";

#
# Tests
#
use_ok "OpenXPKI::Crypto::TokenManager";

my $default_token;
lives_and {
    my $mgmt = OpenXPKI::Crypto::TokenManager->new;
    $default_token = $mgmt->get_system_token({ TYPE => "DEFAULT" });
    ok $default_token;
} 'Get default token';

# prepare test data
$ENV{pwd} = $passwd;
my ($tmp_fh, $tmp) = tempfile(UNLINK => 1);
print $tmp_fh $rsa or die "Could not write key to temp file: $@";
close $tmp_fh;

my $spkac = `openssl spkac -key $tmp -passin env:pwd`;
ok $spkac, 'OpenSSL SPKAC conversion';

# SPKAC needs the raw SPKAC data without the SPKAC= openssl 'header'
$spkac =~ s{\A SPKAC=}{}xms;

## get object
my $csr_spkac = $default_token->get_object({
    DATA => $spkac,
    TYPE => "CSR",
    FORMAT => "SPKAC",
});
ok $csr_spkac, 'get_object()';

## check that all required functions are available and work
foreach my $func ("pubkey_algorithm", "pubkey", "keysize", "modulus", "exponent", "pubkey_hash", "signature_algorithm") {
    ## FIXME: this is a bypass of the API !!!
    my $result = $csr_spkac->$func();
    ok $result, "SPKAC object method $func";
}

1;
