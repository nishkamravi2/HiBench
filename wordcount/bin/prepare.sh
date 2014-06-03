#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -u

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

echo "========== preparing wordcount data=========="
# configure
DIR=`cd $bin/../; pwd`
. "${DIR}/../bin/hibench-config.sh"

. "${DIR}/conf/configure.sh"


# compress check

if [ $MR2 = 0 ]; then
 if [ $COMPRESS -eq 1 ]; then
    COMPRESS_OPT="-D mapred.output.compress=true \
    -D mapred.output.compression.codec=$COMPRESS_CODEC \
    -D mapred.output.compression.type=BLOCK "
 else
    COMPRESS_OPT="-D mapred.output.compress=false"
 fi
else 
 if [ $COMPRESS -eq 1 ]; then
    COMPRESS_OPT="-D mapreduce.output.fileoutputformat.compress=true \
    -D mapreduce.output.fileoutputformat.compress.codec=$COMPRESS_CODEC \
    -D mapreduce.output.fileoutputformat.compress.type=BLOCK "
 else
    COMPRESS_OPT="-D mapreduce.output.fileoutputformat.compress=false"
 fi
fi



# path check
$HADOOP_EXECUTABLE fs -rm -r -skipTrash $INPUT_HDFS

# generate data
if [ $MR2 = 0 ]; then
  $HADOOP_EXECUTABLE jar $HADOOP_EXAMPLES_JAR randomtextwriter \
     $COMPRESS_OPT \
     -D test.randomtextwrite.bytes_per_map=$((${DATASIZE} / ${NUM_MAPS})) \
     -D test.randomtextwrite.maps_per_host=${NUM_MAPS} \
     $INPUT_HDFS
  result=$?
else
  $HADOOP_EXECUTABLE jar $HADOOP_EXAMPLES_JAR randomtextwriter \
     $COMPRESS_OPT \
     -D mapreduce.randomtextwriter.bytespermap=$((${DATASIZE} / ${NUM_MAPS})) \
     -D mapreduce.randomtextwriter.mapsperhost=${NUM_MAPS} \
     $INPUT_HDFS
  result=$?
fi

if [ $result -ne 0 ]
then
    echo "ERROR: Hadoop job failed to run successfully." 
    exit $result
fi
