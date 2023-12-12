#!/bin/bash

test_file="$1"

echo "Welcome to the terminal!"
sleep 1

num=0
while /bin/true; do
    num=$((num+1))
    echo -e -n "\nPlease enter your password #$num: "
    sleep 1
    echo -e -n "\nPlease enter your real password #$num: "
    read -r -s passwd
    if [[ $? != 0 ]]; then
        echo -e "\nERROR during read: $?"
    fi
    echo -e "\nProcessing [$passwd] ..."
    if [[ $passwd == "pwd:1" ]]; then echo "PASSWORD_OK"; else echo "PASSWORD_WRONG"; fi
    if [[ $num == 2 ]]; then break; fi
done

sleep 2
echo "Exiting"

echo "test" > $test_file

exit 33
