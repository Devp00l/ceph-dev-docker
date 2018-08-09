#!/bin/bash

set -e

url=`ceph mgr services | jq .dashboard`

cd /ceph/src/pybind/mgr/dashboard/frontend
jq '.["/api/"].target'=$url proxy.conf.json.sample | jq '.["/ui-api/"].target'=$url > proxy.conf.json
