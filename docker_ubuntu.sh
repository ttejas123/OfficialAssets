# update and install apt
apt-get update
apt-get install nano curl git

# install nvm 
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

# open curr path in docker
if [ "$(docker ps -a -q -f name="$FOLDER_NAME")" ]; then
    echo "Container '$FOLDER_NAME' already exists. Starting it..."
    docker start -i "$FOLDER_NAME"
else
    echo "Container '$FOLDER_NAME' does not exist. Creating and running a new one..."
    docker run -it -v "$(PWD)":/home/"$FOLDER_NAME" --name "$FOLDER_NAME" ubuntu
fi
