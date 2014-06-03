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

echo "========== running bayes bench =========="
# configure
DIR=`cd $bin/../; pwd`
. "${DIR}/../bin/hibench-config.sh"
. "${DIR}/conf/configure.sh"

# compress check
if [ $MR2 = 0 ]; then
  if [ $COMPRESS -eq 1 ]; then
    COMPRESS_OPT="-Dmapred.output.compress=true
    -Dmapred.output.compression.codec=$COMPRESS_CODEC"
  else
    COMPRESS_OPT="-Dmapred.output.compress=false"
  fi
else
  if [ $COMPRESS -eq 1 ]; then
    COMPRESS_OPT="-Dmapreduce.output.fileoutputformat.compress=true
    -Dmapreduce.output.fileoutputformat.compress.codec=$COMPRESS_CODEC"
  else
    COMPRESS_OPT="-Dmapreduce.output.fileoutputformat.compress=false"
  fi
fi

# path check
${HADOOP_EXECUTABLE} fs -rm -r -skipTrash ${OUTPUT_HDFS}

# pre-running
if [ $MR2 = 0 ]; then
 SIZE=$($HADOOP_EXECUTABLE job -history $INPUT_HDFS | grep 'HiBench.Counters.*|BYTES_DATA_GENERATED')
 SIZE=${SIZE##*|}
 SIZE=${SIZE//,/}
fi
START_TIME=`timestamp`

# run bench
$MAHOUT_HOME/bin/mahout seq2sparse \
        $COMPRESS_OPT -i ${INPUT_HDFS} -o ${OUTPUT_HDFS}/vectors  -lnorm -nv  -wt tfidf -ng ${NGRAMS}
result=$?
if [ $result -ne 0 ]
then
    echo "ERROR: Mahout command failed to execute successfully." 
    exit $result
fi

$MAHOUT_HOME/bin/mahout trainnb \
        $COMPRESS_OPT -i ${OUTPUT_HDFS}/vectors/tfidf-vectors -el -o ${OUTPUT_HDFS}/model -li ${OUTPUT_HDFS}/labelindex  -ow --tempDir ${OUTPUT_HDFS}/temp

result=$?
if [ $result -ne 0 ]
then
    echo "ERROR: Mahout command failed to execute successfully."
    exit $result
fi

# post-running
END_TIME=`timestamp`

if [ $MR2 = 0 ]; then
 gen_report "BAYES" ${START_TIME} ${END_TIME} ${SIZE}
else
 gen_report2 "BAYES" ${START_TIME} ${END_TIME} 
fi

