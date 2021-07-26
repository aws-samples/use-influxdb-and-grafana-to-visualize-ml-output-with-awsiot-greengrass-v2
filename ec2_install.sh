apt-get update
apt-get install -y python3-pip zip jq
pip3 install Pillow
pip3 install numpy
pip3 install dlr
git clone https://github.com/aws/aws-iot-device-sdk-python-v2.git
python3 -m pip install ./aws-iot-device-sdk-python-v2