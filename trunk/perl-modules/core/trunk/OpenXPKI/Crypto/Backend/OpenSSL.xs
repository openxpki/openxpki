INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL/XS/X509.xs
INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL/XS/PKCS10.xs
INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL/XS/SPKAC.xs
INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL/XS/CRL.xs

MODULE = OpenXPKI		PACKAGE = OpenXPKI::Crypto::Backend::OpenSSL

void
set_config(config)
	const char * config
    CODE:
	OPENSSL_config (config);
