import json
import boto3

dynamodb = boto3.resource('dynamodb')                # Request AWS DynamoDB
table = dynamodb.Table('lolucode.click-count')          # Retrieve the table name lolucode.click-count
def lambda_handler(event, context):
    response = table.get_item(Key={'id': 1})          # Retrive the item whose id=1
    views = response["Item"]["views"]                 # Extract the "views" attribute from the response
    views +=1
    
    response = table.put_item(Item={                  # Update the value of "views" in the table
        'id': 1,
        'views': views 
    })
    # TODO implement
    return (views)