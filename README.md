# Distributed consensus with CloudHaskell

## Description

Implementation of the Raft distributed consensus algorithm using
CloudHaskell. Work-in-progress.

This repository contains a [project file](./docs/project.org).

## Local setup

Requires [stack](https://docs.haskellstack.org/en/stable/README/) to be
installed. To run a size 3 raft cluster locally:

```
stack install :raft :raft-control
cd dist
docker-compose run raft-control
```

This attaches you to the container running `raft-control`. Hit `<Tab>` to see available commands, or
use the `\inspect` command to see the state of the cluster.

### Simulating partitions

Requires [blockade](https://github.com/worstcase/blockade) to be installed. From
the `./dist` folder, run:

```
./run-blockade
```

Simulate a partition:

```
blockade raft-0 raft-1,raft-2
```
