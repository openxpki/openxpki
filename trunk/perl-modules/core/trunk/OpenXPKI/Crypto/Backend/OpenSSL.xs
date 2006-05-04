INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL/XS/X509.xs
INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL/XS/PKCS10.xs
INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL/XS/SPKAC.xs
INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL/XS/CRL.xs

MODULE = OpenXPKI		PACKAGE = OpenXPKI::Crypto::Backend::OpenSSL

int
set_config(config)
	const char * config
    CODE:
        OPENSSL_load_builtin_modules();
        ENGINE_load_builtin_engines();
        RETVAL = CONF_modules_load_file(config, NULL, 0);
    OUTPUT:
        RETVAL
