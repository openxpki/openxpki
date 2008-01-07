use strict;
use warnings;

use Test::More;
use English;
use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}
require OpenXPKI::XML::Config;

plan tests => 1;

eval {
    my $obj = OpenXPKI::XML::Config->new(CONFIG => "t/20_xml/inheritance_bug.xml");
};

like($EVAL_ERROR, qr(I18N_OPENXPKI_SERVER_XML_CACHE___GET_SUPER_ENTRY_MORE_THAN_ONE_PATH_AND_NO_ID_SPECIFIED));

