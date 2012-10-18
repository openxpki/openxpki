touch index.txt
touch index.txt.attr
echo 00 > serial
`cat ../../cfg.binary.openssl` req -key $NCIPHER_KEY -keyform engine -engine chil -config openssl.cnf -new -out csr.pem
`cat ../../cfg.binary.openssl` ca -config openssl.cnf -selfsign -in csr.pem -keyfile $NCIPHER_KEY -keyform engine -engine chil -utf8 -outdir . -batch -preserveDN -out cacert.pem
`cat ../../cfg.binary.openssl` x509 -in 00.pem -out certs/cacert.pem
rm index.txt index.txt.attr serial index.txt.old index.txt.attr.old serial.old cacert.pem csr.pem 00.pem
