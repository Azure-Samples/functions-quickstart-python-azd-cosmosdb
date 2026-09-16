#!/bin/bash
set -e
./infra/scripts/enablechangefeed.sh
./infra/scripts/createlocalsettings.sh
./infra/scripts/addclientip.sh