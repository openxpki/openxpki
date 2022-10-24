#!/bin/bash

# if [ "$1" != "trace" ]; then exec strace $0 trace 2>&1; fi

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
exit 33
