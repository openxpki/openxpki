INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL/X509.xs
INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL/PKCS10.xs
INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL/SPKAC.xs
INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL/CRL.xs

MODULE = OpenXPKI		PACKAGE = OpenXPKI::Crypto::Backend::OpenSSL

void
set_config(config)
	const char * config
    CODE:
	OPENSSL_config (config);
