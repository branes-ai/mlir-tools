# Install prerequisites
sudo apt update
sudo apt install -y software-properties-common

# Update and install Python 3.10 with dev headers
# Ubuntu provides 3.8, 3.10 and 3.12
sudo apt update
sudo apt install -y python3.10 python3.10-dev python3.10-venv python3.10-distutils

# Verify installation
python3.10 --version
python3.10 -m pip --version
