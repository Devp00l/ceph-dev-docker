#!/bin/bash
echo "source me ;)"

###############################################################################
# aliases
cdbpath="/ceph/src/pybind/mgr/dashboard"
export CEPH_ROOT=/ceph
export CEPH_BUILD_DIR=/ceph/build
alias c-b="cd $cdbpath"
alias cbuild="cd $CEPH_BUILD_DIR"

###############################################################################
# making ceph available
export PATH=$PATH:/ceph/build/bin
function ceph {
    current=$(pwd)
    cbuild
    bin/ceph $@
    cd $current
}
function ceph-compile {
    echo "If your cluster is still running, stop this execution, otherwise hit any key to continue"
    read x
    current=$(pwd)
    prepareCompile
    cbuild
    cmake -DBOOST_J=2 -DWITH_PYTHON3=ON -DWITH_TESTS=OFF -DWITH_CCACHE=ON ..
    ccache make -j2
    cd $current
    ceph-start
    echo "Don't forget to commit this docker if everything is fine!"
    cd $current
}
function prepareCompile {
    current=$(pwd)
    zypper ref
    zypper update -y
    c-b
    pip2 install --upgrade pip
    pip2 install -r requirements.txt
    pip3 install --upgrade pip
    pip3 install -r requirements.txt
    cd /ceph
    ./install-deps.sh
    git submodule update -f --recursive --remote
    git submodule update --init -f --recursive
    chown 1000:1000 -R /ceph
    cd $current
}

###############################################################################
# Starting a single cluster
function ceph-reset {
    ceph-stop
    ceph-start
}
function ceph-stop {
    current=$(pwd)
    cbuild
    ../src/stop.sh
    rm -rf out dev
    cd $current
}
function ceph-start {
    ceph-start-no-cd
    #sleep 10
    cd-reload
    ceph -s
    get-served-at
    chown 1000:1000 -R $cdbpath/frontend/dist
}
function ceph-start-no-cd {
    current=$(pwd)
    cbuild
    RGW=1 MDS=1 MON=1 OSD=3  ../src/vstart.sh -d -n -x
    #sleep 10
    radosgw-admin user create --uid=0 --display-name "hero" --system
    cc-test-pool pool1
    cd $current
}
function cc-test-pool {
    #1 = pool name
    bin/rados mkpool $1
    ceph osd pool application enable $1 rbd
    # file adding missing
}
function get-served-at {
    grep "\[py\] .*Serving" /ceph/build/out/mgr.x.log | \
        grep --color=none -o "[0-9]*$" | \
        sort | uniq | sed "s/^/http:\/\/localhost:/"
}

###############################################################################
# Dashboard related single cluster
function cd-reload {
    cd-stop
    cd-start
}
function cd-stop {
    cd-delete-all-users #enable for role management
    ceph mgr module disable dashboard
    c-b
    find . -name "*.pyc" -exec rm "{}" \;
    cd $current
}
function cd-delete-all-users {
    for i in "${types[@]}"; do
        ceph dashboard ac-user-delete "u-$i"
    done
}
function cd-start {
    ceph config set mgr mgr/dashboard/x/server_port 8383
    ceph mgr module enable dashboard --force
    cd-configure-rgw
    ceph mgr module ls
    cd-create-all-users #enable for role management
    get-served-at
}
function cd-configure-rgw {
    current=$(pwd)
    cbuild
    access=$(radosgw-admin user info --uid=0 | grep -o "access_key.*" | sed 's/.*"\(.*\)",/\1/')
    secret=$(radosgw-admin user info --uid=0 | grep -o "secret_key.*" | sed 's/.*"\(.*\)"/\1/')
    ceph dashboard set-rgw-api-access-key $access
    ceph dashboard set-rgw-api-secret-key $secret
    cd $current
}
function cd-create-all-users {
    types=(read create delete update)
    for i in "${types[@]}"; do
        cd-create-user $i
    done
}
function cd-create-user {
    #$1 should be read / create / update / delete
    userName="u-$1"
    roleName="auto-only-$1"
    ceph dashboard ac-role-create $roleName
    stuff=(hosts config-opt pool osd monitor rbd-image rbd-mirroring iscsi rgw cephfs manager log)
    for i in "${stuff[@]}"; do
        ceph dashboard ac-role-add-scope-perms $roleName $i $1
    done
    ceph dashboard ac-user-create $userName $userName $roleName
    ceph dashboard ac-user-add-roles $userName "auto-only-read"
}
function cd-lint-python {
    current=$(pwd)
    c-b
    tox -e lint
    cd $current
}
function cd-unit-tests {
    current=$(pwd)
    c-b
    tox
    cd $current
}
function cd-api-tests {
    c-b
    ./run-backend-api-tests.sh
    cd $current
}
function cd-api-specific-test {
    c-b
  # ./run-backend-api-tests.sh tasks.mgr.dashboard.test_pool.PoolTest
    ./run-backend-api-tests.sh $1
    cd $current
}
function cd-traceback {
    cd-reload
    traceback-mgr
}
function cd-debug {
    cd-reload
    tail -f /ceph/build/out/mgr.x.log | grep --line-buffered "\[dashboard\] [^N]"
}
function traceback-mgr {
    grep -A 30 -B 30 "Traceback" /ceph/build/out/mgr.x.log
    tail -f /ceph/build/out/mgr.x.log | grep --line-buffered -A 30 -B 30 "Traceback"
}
function debug-mgr {
    tail -f /ceph/build/out/mgr.x.log | grep --line-buffered "\[py\] [^N]"
}

###############################################################################
# Multi cluster usage
function ceph-multi-cluster-start {
    current=$(pwd)
    cbuild
    ceph-stop
    MGR=1 MDS=0 ../src/mstart.sh primary -n
    MGR=1 MDS=0 ../src/mstart.sh secondary -n
    cp run/primary/ceph.conf primary.conf
    cp run/secondary/ceph.conf secondary.conf
    cc-multi-pool primary
    cc-multi-pool secondary
    # starting rbd-mirror daemon in secondary site
    ./bin/rbd-mirror --cluster secondary --log-file=run/secondary/out/rbd-mirror.log
    # enable mirroring pool mode in primary
    ./bin/rbd --cluster primary mirror pool enable rbd pool
    # enable mirroring pool mode in secondary
    ./bin/rbd --cluster secondary mirror pool enable rbd pool
    # add primary cluster to secondary list of peers
    ./bin/rbd --cluster secondary mirror pool peer add rbd client.admin@primary
    # Now the setup is ready, each rbd image that is created in the primary cluster
    # is automatically replicated to the secondary cluster
    cc-multi-image primary img1
    cc-multi-image primary img2
    cd $current
}
function cc-multi-pool {
    #1 = cluster name
    ceph --cluster $1 osd pool create rbd 100 100
    ceph --cluster $1 osd pool application enable rbd rbd
}
function cc-multi-image {
    #1 = cluster name
    # creating $2 and run some write operations
    ./bin/rbd --cluster $1 create --size=1G $2 --image-feature=journaling,exclusive-lock
    ./bin/rbd --cluster $1 bench --io-total=32M --io-type=write --io-pattern=rand $2
}
function ceph-multi-cluster-stop {
    current=$(pwd)
    killall rbd-mirror
    cbuild
    ../src/mstop.sh primary
    ../src/mstop.sh secondary
    rm -f primary.conf
    rm -f secondary.conf
    cd $current
}

