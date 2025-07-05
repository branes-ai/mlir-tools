# Install prerequisites
sudo apt update
sudo apt install -y software-properties-common

# Add deadsnakes PPA
sudo add-apt-repository ppa:deadsnakes/ppa
# Press ENTER when prompted

# Update and install Python 3.9 with dev headers
sudo apt update
sudo apt install -y python3.9 python3.9-dev python3.9-venv python3.9-distutils

# Install pip for Python 3.9
wget https://bootstrap.pypa.io/get-pip.py
python3.9 get-pip.py --user
rm get-pip.py

# Verify installation
python3.9 --version
python3.9 -m pip --version
