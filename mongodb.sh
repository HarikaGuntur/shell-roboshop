#!/bin/bash

USERID=$(id -u)
LOGS_FOLDER="/var/log/shell-roboshop"
LOGS_FILE="/var/log/shell-roboshop/$0.log"
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $USERID -ne 0 ]; then
    echo -e "$R Please run this script with root user access $N" | tee -a $LOGS_FILE
    exit 1
fi

mkdir -p $LOGS_FOLDER

Validate(){
    if [ $1 -ne 0 ]; then
        echo -e "$2 ... $R FAILURE $N" | tee -a $LOGS_FILE
        exit 1
    else
        echo -e "$2 ... $G SUCCESS $N" | tee -a $LOGS_FILE
    fi
}

cp mongo.repo /etc/yum.repos.d/mongo.repo
Validate $? "copying mongo repo"

dnf install mongodb-org -y &>>$LOGS_FILE
Validate $? "installed mongodb"

systemctl enable mongod 
Validate $? "enabled mongodb"

systemctl start mongod 
Validate $? "started mongod"

sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf
Validate $? "allowing remote connections"

systemctl restart mongod
Validate $? "restarted mongodb"
