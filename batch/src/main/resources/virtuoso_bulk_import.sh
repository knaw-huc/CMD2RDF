#!/bin/sh
echo "Executing bulk loader script."
echo "Host / port: $1"
echo "username: $2"
echo "password: $3"
echo "rdf directory: $4"

isql $1 $2 $3 exec="ld_dir_all('$4', '*.rdf', 'http://eko.indarto/eko.rdf');"
isql $1 $2 $3 exec="rdf_loader_run();"
isql $1 $2 $3 exec="checkpoint;"

echo "Bulk loader: Finish."
