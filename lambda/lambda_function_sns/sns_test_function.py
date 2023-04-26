from datetime import datetime
import json

def lambda_handler(event, context):
    current_datetime_str = datetime.now().strftime('%d-%m-%Y %H:%M:%S')
    
    try:
        body_string = event['Records'][0]['body']
        body_json = json.loads(body_string)
        message = body_json['Message'].replace('\n', '')
    
        print(f"Message; {message}, timestamp: {current_datetime_str}")
    except Exception as err:
        print(f"{current_datetime_str}:{err}")

    return {
        'statusCode': 200,
        'body': json.dumps(current_datetime_str)
    }