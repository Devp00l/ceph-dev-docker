# ceph-dev-docker

The purpose of this docker image is to ease the local development of Ceph, by
providing a container-based runtime and development environment (based on
openSUSE "Tumbleweed").

It requires a local git clone to start up a
[vStart](http://docs.ceph.com/docs/master/dev/dev_cluster_deployement/)
environment.

## Usage

### docker user group

`docker` command requires root privileges.
To remove this requirement you can join the `docker` user group.

### Build the Image

From inside this project's git repo, run the following command:

    # docker build -t ceph-dev-docker .

You should now have two additional images in your local Docker repository, named
`ceph-dev-docker` and `docker.io/opensuse`:

    # docker images
    REPOSITORY           TAG                 IMAGE ID            CREATED             SIZE
    ceph-dev-docker      latest              559deb8b9b4f        15 minutes ago      242 MB
    docker.io/opensuse   tumbleweed          f27ade5f6fe7        11 days ago         104 MB

### Clone Ceph

Somewhere else on your host system, create a local clone of the Ceph git
repository. Replace `<ceph-repository>` with the remote git repo you want to
clone from, e.g. `https://github.com/ceph/ceph.git`:

    # cd <workdir>
    # git clone <ceph-repository>
    # cd ceph

Now switch or create your development branch using `git checkout` or `git
branch`.

### image build

    # cd /ceph
    # ./install-deps.sh
    # ./do_cmake.sh
    # cd /ceph/build
    # cmake -DWITH_PYTHON3=ON -DWITH_TESTS=NO ..
    # make -j4
    # pip2 install -r /ceph/src/pybind/mgr/dashboard_v2/requirements.txt

### Starting the Container and building Ceph

Now start up the container, by mounting the local git clone directory as
`/ceph`:
=======
After this command has finished you can close the running docker

### Running the container with all dependencies installed

    # docker run -itd \
      -v $PWD:/ceph \
      -v <CCACHE_DIR>:/root/.ccache \
      --net=host \
      --name=ceph-dev \
      --hostname=ceph-dev \
      --add-host=ceph-dev:127.0.0.1 \
      ceph-dev-docker \
      /bin/bash

Lets walk through some of the flags from the above command:
- `-d`: runs the container shell in detach mode
 - `<CCACHE_DIR>`: the directory where ccache will store its data
 - `--name`: custom name for the container, this can be used for managing
    the container
 - `--hostname`: custom hostname for the docker container, it helps to
    distinguish one container from another
 - `--add-host`: fixes the problem with resolving hostname inside docker

After running this command you will have a running docker container.
Now, anytime you want to access the container shell you just have to run

    # docker attach ceph-dev

Inside the container, you can now call `setup-ceph`, which will install all the
required build dependencies and then build Ceph from source.

    (docker)# setup-ceph

### Docker container lifecycle

To start a container run,

    # docker start ceph-dev

And to attach to a running container shell,

    # docker attach ceph-dev

If you want to detach from the container and stop the container,

    (docker)# exit

However if you want to simply detach, without stoping the container,
which would allow you to reattach at a later time,

    (docker)# CTRL+P CTRL+Q

Finally, to stop the container,

    # docker stop ceph-dev

## Multiple docker container

If you want to run multiple docker container, you just need to modify the
previous `docker run` command with a different local ceph directory and replace
`ceph-dev` with a new value.

For example:

    # docker run -itd \
      -v $PWD:/ceph \
      -v <CCACHE_DIR>:/root/.ccache \
      --net=host \
      --name=new-ceph-container \
      --hostname=new-ceph-container \
      --add-host=new-ceph-container:127.0.0.1 \
      ceph-dev-docker \
      /bin/bash

Now if you want to access this container just run,

    # docker attacch new-ceph-container

### Start Ceph Development Environment

To start up the compiled Ceph cluster, you can use the `vstart.sh` script, which
spawns up an entire cluster (MONs, OSDs, Mgr) in your development environment.
See the
[documentation](http://docs.ceph.com/docs/master/dev/dev_cluster_deployement/)
and the output of `vstart.sh --help` for details.

To start an environment from scratch with debugging enabled, use the following
command:

    (docker)# cd /ceph/build
    (docker)# ../src/vstart.sh -d -n -x

**Note:** The `-d` option enables debug output. Keep a close eye on the growth
of the log files created in `build/out`, as they can grow very quickly (several
GB within a few hours).
### Test Ceph Development Environment

    (docker)# cd /ceph/build
    (docker)# bin/ceph -s

### Stop Ceph development environment

    (docker)# cd /ceph/build
    (docker)# ../src/stop.sh
