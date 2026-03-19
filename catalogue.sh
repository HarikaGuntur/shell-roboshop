#!/bin/bash

set -e

USERID=$(id -u)
LOGS_FOLDER="/var/log/shell-roboshop"
LOGS_FILE="$LOGS_FOLDER/$(basename "$0").log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MONGODB_HOST="mongodb.dawshars.online"

mkdir -p $LOGS_FOLDER

echo "Script started executing at $(date)" | tee -a $LOGS_FILE

# Root check
if [ "$USERID" -ne 0 ]; then
    echo -e "$R Please run this script with root user access $N" | tee -a $LOGS_FILE
    exit 1
fi

# Validation function
VALIDATE() {
    if [ "$1" -ne 0 ]; then
        echo -e "$2 ... $R FAILURE $N" | tee -a $LOGS_FILE
        exit 1
    else
        echo -e "$2 ... $G SUCCESS $N" | tee -a $LOGS_FILE
    fi
}

# NodeJS setup
dnf module disable nodejs -y &>>$LOGS_FILE
VALIDATE $? "Disabling NodeJS Default version"

dnf module enable nodejs:20 -y &>>$LOGS_FILE
VALIDATE $? "Enabling NodeJS 20"

dnf install nodejs -y &>>$LOGS_FILE
VALIDATE $? "Installing NodeJS"

# Create roboshop user
id roboshop &>>$LOGS_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOGS_FILE
    VALIDATE $? "Creating system user"
else
    echo -e "Roboshop user already exists ... $Y SKIPPING $N" | tee -a $LOGS_FILE
fi

# App setup
mkdir -p /app
VALIDATE $? "Creating app directory"

curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>>$LOGS_FILE
VALIDATE $? "Downloading catalogue code"

cd /app
VALIDATE $? "Changing to app directory"

rm -rf /app/*
VALIDATE $? "Removing old code"

unzip /tmp/catalogue.zip &>>$LOGS_FILE
VALIDATE $? "Unzipping catalogue code"

npm install &>>$LOGS_FILE
VALIDATE $? "Installing dependencies"

# Systemd setup
cp $SCRIPT_DIR/catalogue.service /etc/systemd/system/catalogue.service
VALIDATE $? "Copying catalogue service file"

systemctl daemon-reload &>>$LOGS_FILE
VALIDATE $? "Reloading systemctl"

systemctl enable catalogue &>>$LOGS_FILE
systemctl start catalogue &>>$LOGS_FILE
VALIDATE $? "Starting and enabling catalogue"

# MongoDB client setup
cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongo.repo
VALIDATE $? "Copying MongoDB repo"

dnf install mongodb-mongosh -y &>>$LOGS_FILE
VALIDATE $? "Installing mongosh"

# Load data into MongoDB
INDEX=$(mongosh --host "$MONGODB_HOST" --quiet --eval 'db.getMongo().getDBNames().indexOf("catalogue")' 2>>$LOGS_FILE)

echo "MongoDB INDEX value: $INDEX" >>$LOGS_FILE

if [[ -z "$INDEX" || "$INDEX" -lt 0 ]]; then
    mongosh --host "$MONGODB_HOST" </app/db/master-data.js &>>$LOGS_FILE
    VALIDATE $? "Loading catalogue data into MongoDB"
else
    echo -e "Products already loaded ... $Y SKIPPING $N" | tee -a $LOGS_FILE
fi

# Restart service
systemctl restart catalogue &>>$LOGS_FILE
VALIDATE $? "Restarting catalogue"

echo -e "$G Script completed successfully $N"