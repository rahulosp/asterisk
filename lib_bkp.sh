#!/bin/bash

echo "Trying to copy the files to backup directory"
cp -ar /var/lib/asterisk/* /data/var/lib/asterisk/
echo "Copy completed."
