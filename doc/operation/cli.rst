Command Line Interface (CLI)
=============================

Overview
--------

Since version 3.32.0 OpenXPKI provides a new command line interface called `oxi`. 
The `oxi` tool offers a wide range of functionality including token management, certificate operations, workflow management, and system administration.

The `oxi` command has built-in documentation accessible via the man page system and help commands. You can access help using:

.. code-block:: bash

    # Show general help
    oxi --help
    
    # Show help for a specific command
    oxi help COMMAND
    
    # Show help for a specific subcommand  
    oxi COMMAND SUBCOMMAND --help

Authentication Setup
--------------------

Before you can use most `oxi` commands, you need to set up proper authentication. Many commands require privileged access and will fail with the error "Received ProtectedCommand without proper authentication" if authentication is not properly configured.

Creating Authentication Keys
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To set up CLI authentication, you need to create a key pair:

.. code-block:: bash

    # Generate a new authentication key pair
    oxi cli create

This command will:

* Generate a new ECC key pair
* Prompt you for an optional password to encrypt the private key
* Output the results in YAML format with three fields:
  
  - ``id``: The key identifier/thumbprint
  - ``private``: The private key in PEM format (encrypted if password was provided)
  - ``public``: The public key in PEM format

Example output:

.. code-block:: yaml

    ---
    id: 7H3PCtXIGcRQqSR6OoAJxgyuiTRVjr63LsasHkmZEbI
    private: |
      -----BEGIN EC PRIVATE KEY-----
      Proc-Type: 4,ENCRYPTED
      DEK-Info: AES-256-CBC,32c7acaba9dadd1056d15307f44ce19a
      
      fInTO8luroJ2RaTqjYjHr79WeoR7AI42Q1h6ZoUDsTg9iKLT0QButBdfo8GU/jRd
      ...
      -----END EC PRIVATE KEY-----
    public: |
      -----BEGIN PUBLIC KEY-----
      MIIBMzCB7AYHKoZIzj0CATCB4AIBATAsBgcqhkjOPQEBAiEA/////wAAAAEAAAAA
      ...
      -----END PUBLIC KEY-----

Configuring the Private Key
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Save the private key to a file and set appropriate permissions:

.. code-block:: bash

    # Create the directory if it doesn't exist
    mkdir -p ~/.oxi
    
    # Save the private key (copy the entire 'private:' section from oxi cli create output)
    cat > ~/.oxi/client.key << 'EOF'
    -----BEGIN EC PRIVATE KEY-----
    Proc-Type: 4,ENCRYPTED
    DEK-Info: AES-256-CBC,32c7acaba9dadd1056d15307f44ce19a

    fInTO8luroJ2RaTqjYjHr79WeoR7AI42Q1h6ZoUDsTg9iKLT0QButBdfo8GU/jRd
    ... (rest of your private key) ...
    -----END EC PRIVATE KEY-----
    EOF
    
    # Set secure permissions
    chmod 600 ~/.oxi/client.key

Configuring the System
^^^^^^^^^^^^^^^^^^^^^^^

Add the public key to the system configuration by editing `/etc/openxpki/config.d/system/cli.yaml`:

.. code-block:: yaml

    # Add your public key to the auth section
    # Use the 'id' value from oxi cli create as the key name
    auth:
        7H3PCtXIGcRQqSR6OoAJxgyuiTRVjr63LsasHkmZEbI:
            type: client
            # Copy the entire 'public:' section from oxi cli create output
            key: |
                -----BEGIN PUBLIC KEY-----
                MIIBMzCB7AYHKoZIzj0CATCB4AIBATAsBgcqhkjOPQEBAiEA/////wAAAAEAAAAA
                AAAAAAAAAAAAAAAAD///////////////8wRAQg/////wAAAAEAAAAAAAAAAAAAAAD/////
                //////////wEIFrGNdiqOpPns+u9VXaYhrxlHQawzFOw9jvOPD4n0mBLBEEEaxfR
                8uEsQkf4vOblY6RA8ncDfYEt6zOg9KE5RdiYwpZP40Li/hp/m47n60p8D54WK84z
                V2sxXs7LtkBoN79R9QIhAP////8AAAAA//////////+85vqtpxeehPO5ysL8YyVR
                AgEBA0IABAUFd8y5ebh/hQhr99X6XkcrjTiBY9wBrdbmk16BJLr5BMxu4ETaGjAZ
                bHrg253Oviley3IX/IiUySxh+Hgv2Zs=
                -----END PUBLIC KEY-----

Make sure the YAML formatting is correct - improper indentation will break the configuration. 
Replace the example key ID and public key with the actual values from your `oxi cli create` output.

After updating the configuration file, you must restart the OpenXPKI client service for the changes to take effect:

.. code-block:: bash

    # Restart the client service to load the new authentication configuration
    systemctl restart openxpki-clientd


Using the CLI
^^^^^^^^^^^^^

Once authentication is configured, you can use `oxi` commands that require privileges:

.. code-block:: bash

    # Example: Add a SCEP token
    oxi token add --realm democa --type scep --cert scep.crt --key scep.key
    
    # Example: List certificates
    oxi certificate list --realm democa

Alternative Authentication
^^^^^^^^^^^^^^^^^^^^^^^^^^^

You can also specify a custom key file location:

.. code-block:: bash

    # Use a custom key file
    oxi --auth-key /path/to/custom/key.pem COMMAND SUBCOMMAND

For automated scripts, you can set the passphrase via environment variable:

.. code-block:: bash

    export OPENXPKI_CLIENT_KEY_PASSPHRASE="your_passphrase"
    oxi COMMAND SUBCOMMAND

Available Commands
------------------

The `oxi` tool provides the following commands:

* **acme** - Handle account registrations for the NICE ACME backend.
* **alias** - Show and handle alias configuration.
* **api** - Run API commands.
* **cli** - Show and handle configuration of this CLI tool.
* **config** - Show and handle system configuration.
* **datapool** - Manage datapool items.
* **token** - Show and handle token configuration.
* **workflow** - Show and interact with workflows.

For detailed information about any specific command, refer to the built-in help system as described in the Overview section. 