# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
import time
import json
import sys
import argparse
from six.moves import input
import awsiot.greengrasscoreipc
import awsiot.greengrasscoreipc.client as client
from data2influxdb_v2test import write2influxdb
from awsiot.greengrasscoreipc.model import (
    SubscribeToTopicRequest,
    SubscriptionResponseMessage
)

TIMEOUT = 10

ot_cloud_topic = "from/MLoutput/client"
class StreamHandler(client.SubscribeToTopicStreamHandler):
    def __init__(self, token_string, url, bucket_name, org, measurement_name):
        super().__init__()
        self.token_string = token_string
        self.url = url
        self.bucket_name = bucket_name
        self.org = org
        self.measurement_name = measurement_name

    def on_stream_event(self, event: SubscriptionResponseMessage):
        print("received streaming event")
        message_string = str(event.binary_message.message, "utf-8")
        inputs= json.loads(message_string)
        print(message_string)

        writerecord= write2influxdb()
        writerecord.write_data(inputs, self.token_string, self.url, self.bucket_name,self.org, self.measurement_name)
        print(self.bucket_name)
    def on_stream_error(self, error: Exception) -> bool:
        return True

    def on_stream_closed(self) -> None:
        pass


def main():
    parser = argparse.ArgumentParser(description='Parsing arguments')
    parser.add_argument('-t', '--topic',
                       type=str,
                       help='the path to model', default="from/MLoutput/client")
    parser.add_argument('-token', '--token_string',
                       type=str,
                       help='token authentification', default="bgu9Ws-IZ2FErckdSHvYXJAJmOwIDNZkMy2CP70AwzBGwLnzItDnUkDSyOYyS7_LRwfuL0wylecFE6yP5bsjNQ==")
    parser.add_argument('-u', '--url',
                       type=str,
                       help='url', default='http://localhost:8086')
    parser.add_argument('-b', '--bucket_name',
                       type=str,
                       help='InfluxDB bucket name', default='mloutput')
    parser.add_argument('-o', '--org',
                       type=str,
                       help='InfluxDB organization name', default='ggv2demo')
    parser.add_argument('-m', '--measurement_name',
                       type=str,
                   help='InfluxDB measurement name', default='MLoutput_integration')
    args = parser.parse_args()
    print(args.bucket_name)
    ipc_client = awsiot.greengrasscoreipc.connect()
    request = SubscribeToTopicRequest()
    request.topic = args.topic
    handler = StreamHandler(args.token_string, args.url, args.bucket_name, args.org, args.measurement_name)
    operation = ipc_client.new_subscribe_to_topic(handler)
    future = operation.activate(request)
    future.result(TIMEOUT)
    # Keep the main thread alive, or the process will exit.
    while True:
        try:
            selection = input()
        except:
            time.sleep(1)

if __name__ == "__main__":
    main()
