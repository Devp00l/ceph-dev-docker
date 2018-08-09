#!/bin/bash

importDashboard () {
  jsonFile=$(cat $1)
  curl 'http://admin:admin@localhost:3000/api/dashboards/import' \
           -H "Content-Type: application/json" \
           -H "Accept: application/json" \
           --data-binary "{\"dashboard\":$jsonFile,\"overwrite\":true,\"inputs\":[],\"folderId\":0}" --compressed
}

for i in `find ./Dashboards -name "*.json"`; do
  importDashboard $i
done
