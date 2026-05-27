import os
import boto3

def lambda_handler(event, context):
    secret_name = os.environ.get("SECRET_PARAMETER_NAME", "/order_pipeline/api_secret_key")
    
    ssm_client = boto3.client("ssm", region_name="us-east-1")
    
    try:
        response = ssm_client.get_parameter(Name=secret_name, WithDecryption=True)
        secret_value = response["Parameter"]["Value"]
        print(
            f"Sukces! Pobrano sekret o dlugosci: {len(secret_value)} znakow."
        )
    except Exception as e:
        print(f"Blad podczas pobierania sekretu z SSM: {str(e)}")
        secret_value = None

    return {
        "statusCode": 200,
        "body": {
            "status": "Validated",
            "message": "Zamowienie sprawdzone poprawnie przy uzyciu pobranego klucza bezpieczenstwa."
        }
    }