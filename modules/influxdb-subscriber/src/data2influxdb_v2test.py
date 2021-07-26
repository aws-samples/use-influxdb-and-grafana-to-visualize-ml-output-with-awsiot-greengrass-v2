from influxdb_client.client.write_api import SYNCHRONOUS

from influxdb_client import InfluxDBClient, Point
import json
import sys
import traceback

#Influxdb tag name, you can replace it with your own tag values
tag_name = "origin"
tagkey = "MLresult"

class write2influxdb(object):
    @staticmethod
    def write_data(payload_message, token_string, url, bucket_name, org, measurement_name):
        bucket = bucket_name
        #Create a Influxdb client and write each datapoint from JSON message to influxdB
        with InfluxDBClient(url, token=token_string, org=org) as client:
            with client.write_api(write_options=SYNCHRONOUS) as write_api:
                print('*** Write Points ***')
                payload_message['Picture'] = "data:image/png;base64, " + payload_message['Picture']
                dictionary = [{"measurement": measurement_name,"tags": {tag_name: tagkey},"fields": payload_message}]
                try:
                    print("Write")
                    write_api.write(bucket=bucket,record=dictionary)
                except Exception as e:
                    print(sys.exc_info())
                    traceback.print_exc()
                print('***Wirte Points Finished ***')
if __name__ == '__main__':
    print('Data to InfluxDB bridge')
    message = {}
    #InfluxdB Database information
    token_string = 'tCGBk3phIJGWZ2ovMVDuYfN2LCVu8KatBXGLoI9cpwMXZMr--RcWCn4s8LafAF6BjtAWYTp71Bo4F0UvZ-amSA=='
    bucket_name = 'mloutput'
    url='http://localhost:8086'
    org='ggv2demo'
    measurement_name = "MLoutput_imag"

    writerecord= write2influxdb()
    writerecord.write_data(message, token_string, url, bucket_name, org, measurement_name)
