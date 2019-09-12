
INCLUDE: OpenXPKI/Crypto/Backend/OpenSSL/XS/ECDH.xs

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
