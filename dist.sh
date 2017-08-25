#!/bin/bash

# build locally
git pull
sbt dist

# unzip
./dist-play-app-initd.sh stop
unzip -o ./target/universal/com-liao0007-jh-1.0-SNAPSHOT.zip -d /var/www/
rm ./target/universal/com-liao0007-jh-1.0-SNAPSHOT.zip

# restart
./dist-play-app-initd.sh start
