#!/bin/bash

./qat_ia_tools.sh -c
./qat_ia_tools.sh -u
./qat_ia_tools.sh -s val
./qat_ia_tools.sh -s dev
./qat_ia_tools.sh -s integ
./qat_ia_tools.sh -s cp_integ
./qat_ia_tools.sh -p

#test build tools
./qat_ia_tools.sh -d adf
./qat_ia_tools.sh -d integ
./qat_ia_tools.sh -d rm
./qat_ia_tools.sh -d local
./qat_ia_tools.sh -b all
