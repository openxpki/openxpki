This are long living sample certificates to be used in test environments.

A new set may be created by running the following commands:

```bash
tempdir=$(mktemp -d)

# create sample certs
cp /repo/config/contrib/sampleconfig.sh $tempdir/
chmod 0755 $tempdir/sampleconfig.sh

perl -pe 's/openxpkictl start/echo "NO! We stop here"\nexit/' -i $tempdir/sampleconfig.sh
perl -pe 's/^(.?DAYS)=.*/$1="25585"/' -i $tempdir/sampleconfig.sh

$tempdir/sampleconfig.sh $tempdir

cp $tempdir/OpenXPKI_{Root_CA,DataVault,Issuing_CA,SCEP_RA}.{crt,key} /repo/tools/testenv/certificates/
```
