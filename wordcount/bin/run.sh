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

echo "========== running wordcount bench =========="
# configure
DIR=`cd $bin/../; pwd`
. "${DIR}/../bin/hibench-config.sh"
. "${DIR}/conf/configure.sh"

# compress

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
    -D mapreduce.output.fileoutputformat.compress.type=BLOCK \
    -D mapreduce.output.fileoutputformat.compress.codec=$COMPRESS_CODEC"
 else
    COMPRESS_OPT="-D mapreduce.output.fileoutputformat.compress=false"
 fi
fi

# path check
$HADOOP_EXECUTABLE fs -rm -r  -skipTrash $OUTPUT_HDFS

# pre-running

if [ $MR2 = 0 ]; then
 SIZE=$($HADOOP_EXECUTABLE job -history $INPUT_HDFS | grep 'org.apache.hadoop.examples.RandomTextWriter$Counters.*|BYTES_WRITTEN')
 SIZE=${SIZE##*|}
 SIZE=${SIZE//,/}
fi

START_TIME=`timestamp`


echo $HADOOP_EXECUTABLE jar $HADOOP_EXAMPLES_JAR wordcount \
    $COMPRESS_OPT \
    -D mapreduce.job.reduces=${NUM_REDS} \
    -D mapred.reduce.tasks=${NUM_REDS} \
    -D mapreduce.job.inputformat.class=org.apache.hadoop.mapreduce.lib.input.SequenceFileInputFormat \
    -D mapreduce.job.outputformat.class=org.apache.hadoop.mapreduce.lib.output.SequenceFileOutputFormat \
    $INPUT_HDFS $OUTPUT_HDFS


# run bench
$HADOOP_EXECUTABLE jar $HADOOP_EXAMPLES_JAR wordcount \
    $COMPRESS_OPT \
    -D mapreduce.job.reduces=${NUM_REDS} \
    -D mapred.reduce.tasks=${NUM_REDS} \
    -D mapreduce.job.inputformat.class=org.apache.hadoop.mapreduce.lib.input.SequenceFileInputFormat \
    -D mapreduce.job.outputformat.class=org.apache.hadoop.mapreduce.lib.output.SequenceFileOutputFormat \
    $INPUT_HDFS $OUTPUT_HDFS
result=$?
if [ $result -ne 0 ]
then
    echo "ERROR: Hadoop job failed to run successfully." 
    exit $result
fi

# post-running
END_TIME=`timestamp`

if [ $MR2 = 0 ]; then
 gen_report "WORDCOUNT" ${START_TIME} ${END_TIME} ${SIZE}
else 
 gen_report2 "WORDCOUNT" ${START_TIME} ${END_TIME}
fi
