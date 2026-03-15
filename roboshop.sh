#! /bin/bash

SG_ID="sg-058daa4784c0f2eb6"
AMI_ID="ami-0220d79f3f480ecf5"
ZONE_ID="Z05351691ZA9WBKZO03PA"
DOMAIN_NAME="dawshars.online"


for instance in $@
do

    INSTANCE_ID=$( aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type "t3.micro" \
    --security-group-ids $SG_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
    --query 'Instances[0].InstanceId' \
    --output text )

   
    if [ $instance == "frontend" ]; then
        IP=$(
            aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query 'Reservations[].Instances[].PublicIpAddress' \
            --output text
        )
        RECORD_NAME="$DOMAIN_NAME" #dawshars.online
    
    else
        IP=$(
            aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query 'Reservations[].Instances[].PrivateIpAddress' \
            --output text
        )
         RECORD_NAME="$instance.$DOMAIN_NAME" # mongodb.dawshars.online
    fi

    echo "IP Address: $IP"

 aws route53 change-resource-record-sets \
--hosted-zone-id $ZONE_ID \
--change-batch '
{
  "Comment": "Updating record",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name":"'$RECORD_NAME'",
        "Type": "A",
        "TTL": 1,
        "ResourceRecords": [
          {
            "Value": "'$IP'"
          }
        ]
      }
    }
  ]
}
'
 echo "record updated for $instance"


done

