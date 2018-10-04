use strict;
use warnings;

use OpenXPKI;

package OpenXPKI::Crypto::Backend::OpenSSL::ECDH;

sub new_ec_keypair{
  my $group_nid = shift;
  my $key;

  if( (!defined $group_nid) or ($group_nid eq "") ){
      OpenXPKI::Exception->throw (
            message => "Missing parameter EC NID");
  }

  if( $group_nid !~ /[0-9]+/ ){
      OpenXPKI::Exception->throw (
            message => "parameter EC NID is not numeric");
  }


  eval { $key = OpenXPKI::Crypto::Backend::OpenSSL::ECDH::__new_ec_keypair($group_nid); };

  if ( $@ ne "" )
  {
           OpenXPKI::Exception->throw (
            message => $@);
  }

  return $key

}

sub get_ec_pub_key {
 my $ECKey = shift;
 my $pubkey;

 if( (!defined $ECKey) or ($ECKey eq "") ){
      OpenXPKI::Exception->throw (
        message => "Missing parameter ECKey");
 }

  $pubkey = OpenXPKI::Crypto::Backend::OpenSSL::ECDH::__get_ec_pub_key($ECKey);

 return $pubkey;
}

sub get_ecdh_key {
  my $in_pub_ec_key = shift;
  my $ecdhkey;
  my $out_ec_key= shift;
  my $out_ec_pub_key= "";

  if( (!defined $in_pub_ec_key) or ($in_pub_ec_key eq "") ){
    OpenXPKI::Exception->throw (
        message => "Missing parameter EC Peer PubKey");
  }

  if( (!defined $out_ec_key) ){
     $out_ec_key = "";
  }


  eval { $ecdhkey = OpenXPKI::Crypto::Backend::OpenSSL::ECDH::__get_ecdh_key($in_pub_ec_key,$out_ec_key,$out_ec_pub_key);};

  if ( $@ ne "" )
  {
      OpenXPKI::Exception->throw (
        message => $@);
  }

  return { 'ECDHKey' => $ecdhkey ,
           'PEMECKey' => $out_ec_key ,
           'PEMECPubKey' => $out_ec_pub_key };
}

1;