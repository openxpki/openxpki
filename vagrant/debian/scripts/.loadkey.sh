#!/bin/bash

KEY=$(</dev/stdin)

# Let .gpg directory be a memory-fs
rm -rf ~/.gnupg/;
rm -rf /dev/shm/.gnupg
mkdir -p /dev/shm/.gnupg;
ln -s /dev/shm/.gnupg ~/.gnupg;

# Import the KEY from stdin
echo "$KEY" | gpg --import

