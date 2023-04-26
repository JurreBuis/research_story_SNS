from datetime import datetime
import json

def lambda_handler(event, context):
    current_datetime_str = datetime.now().strftime('%d-%m-%Y %H:%M:%S')
    
    print(f"de tijd is: {current_datetime_str}")

    return {
        'statusCode': 200,
        'body': json.dumps(current_datetime_str)
    }