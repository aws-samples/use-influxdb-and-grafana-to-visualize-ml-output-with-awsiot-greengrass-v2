from PIL import Image
import numpy as np
import dlr
import time
import awsiot.greengrasscoreipc
from awsiot.greengrasscoreipc.model import (
    PublishToTopicRequest,
    PublishMessage,
    BinaryMessage
)
import json
import sys
import argparse
import base64
from datetime import datetime


TIMEOUT = 10
PUBLISH_TOPIC = 'from/MLoutput/client'
TEMP_IMG_PATH = '/dev/shm/temp.jpg'
OUTGOING_MSG_FORMAT = {
    'CameraDeviceName': 'AWS Panorama Camera',
    'JudegedBy': "Resnet-18",
    'CameraTrigger': '1',
    'CaptureStatusCode': '200',
    'CaptureStatusMessage': 'Ok',
    'RetryCount': '0',
    'InferenceTotalTime': {},
    'InferenceStartTime': {},
    'InferenceEndTime':{},
    'Prediction': {},
    'Probability': {},
    'Picture': {}
}

def softmax(x):
    """Compute softmax values for each sets of scores in x."""
    e_x = np.exp(x - np.max(x))
    return e_x / e_x.sum()

def publishResults(ipc_client, topic, message):
    print("step info: {}".format(message))
    print('topic', topic)
    print("before publishing: {}".format(time.time()))
    request = PublishToTopicRequest()
    request.topic = topic
    publish_message = PublishMessage()
    publish_message.binary_message = BinaryMessage()
    publish_message.binary_message.message = bytes(json.dumps(message), "utf-8")
    request.publish_message = publish_message
    operation = ipc_client.new_publish_to_topic()
    operation.activate(request)
    futureResponse = operation.get_response()
    try:
        futureResponse.result(TIMEOUT)
        print("after publishing: {}".format(time.time()))
        print('Successfully published to topic: ' + topic)
    except Exception as e:
        print('Exception while publishing to topic: ' +
                topic, file=sys.stderr)
        raise e


def main():
    print("==============")
    print("AiTPS Software")
    print("==============")
    parser = argparse.ArgumentParser(description='Fuel Pump')
    ipc_client = awsiot.greengrasscoreipc.connect()

    # # reading the input arguemenets

    parser.add_argument('--model',
                        help='model', default='./model')

    parser.add_argument('--class_names',
                        help='class_names', default='./obj.names')

    parser.add_argument('--input',
                        help='input file path', default='./dog.jpg')


    args = parser.parse_args()
    while True:
        try:
            start_time = datetime.utcnow()
            input_image = Image.open(args.input).resize((224,224))
            input_image.save(TEMP_IMG_PATH)
            input_matrix = (np.array(input_image) / 255 - [0.485, 0.456, 0.406])/[0.229, 0.224, 0.225]
            transposed = np.transpose(input_matrix, (2, 0, 1))
            model = dlr.DLRModel(args.model, 'cpu', 0)
            res = softmax(model.run(transposed)[0][0])
            pred = np.argmax(res)
            prob = res[pred]
            image_bytes = None
            with open(TEMP_IMG_PATH, "rb") as imageFile:
                image_bytes = base64.b64encode(imageFile.read()).decode('utf8')
            end_time = datetime.utcnow()
            delta = end_time - start_time
            total_time = delta.total_seconds() * 1000
            start_time_str = start_time.strftime("%Y-%m-%d %H:%M:%S.%f")
            end_time_str = end_time.strftime("%Y-%m-%d %H:%M:%S.%f")
            
            outgoing_msg = OUTGOING_MSG_FORMAT
            outgoing_msg['InferenceTotalTime'] = total_time
            outgoing_msg['InferenceStartTime'] = start_time_str
            outgoing_msg['InferenceEndTime'] = end_time_str
            outgoing_msg['Prediction'] = str(pred)
            outgoing_msg['Probability'] = str(prob)
            outgoing_msg['Picture'] = image_bytes
            publishResults(ipc_client, PUBLISH_TOPIC, outgoing_msg)
            time.sleep(5)
        except Exception as e:
            print(e)


if __name__ == "__main__":
    main()
