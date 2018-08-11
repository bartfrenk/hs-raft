docker rm -f raft-0
docker rm -f raft-1
docker rm -f raft-2
docker network rm raft-net
docker network create raft-net --subnet 10.20.0.0/16
docker run -d --name raft-0 --net raft-net --ip 10.20.0.10 bartfrenk/raft -n 3 --host 10.20.0.10
docker run -d --name raft-1 --net raft-net --ip 10.20.0.11 bartfrenk/raft -n 3 --host 10.20.0.11
docker run -d --name raft-2 --net raft-net --ip 10.20.0.12 bartfrenk/raft -n 3 --host 10.20.0.12

