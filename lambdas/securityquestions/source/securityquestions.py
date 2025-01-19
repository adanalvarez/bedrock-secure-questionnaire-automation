import json
import logging
import os
import csv
import io
import time
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Triggered by an S3 'ObjectCreated' event. Processes a text file containing questions,
    retrieves answers using AWS Bedrock, and uploads a CSV with the questions and answers.
    """

    # Load and validate environment variables
    knowledge_base_id = os.environ.get("KNOWLEDGE_BASE_ID")
    model_arn = os.environ.get("MODEL_ARN")
    region_name = os.environ.get("REGION_NAME", "us-east-1")

    if not all([knowledge_base_id, model_arn]):
        logger.error("Missing required environment variables: KNOWLEDGE_BASE_ID, MODEL_ARN.")
        return error_response(400, "Missing required environment variables.")

    # Parse the S3 event to get the file details
    try:
        input_bucket, input_key = parse_s3_event(event)
        logger.info(f"Triggered by new file in s3://{input_bucket}/{input_key}")
    except ValueError as e:
        logger.error(f"Error parsing S3 event: {e}")
        return error_response(400, "Malformed S3 event.")

    # Initialize AWS clients
    s3_client = boto3.client("s3", region_name=region_name)
    bedrock_client = boto3.client("bedrock-agent-runtime", region_name=region_name)

    # Read the uploaded file from S3
    try:
        questions = read_file_from_s3(s3_client, input_bucket, input_key)
        logger.info(f"Found {len(questions)} questions in {input_key}")
    except Exception as e:
        logger.error(f"Error reading file from S3: {e}")
        return error_response(500, "Error reading input file from S3.")

    # Generate answers for each question
    answers = []
    for question in questions:
        answer = call_bedrock_with_retries(
            bedrock_client,
            knowledge_base_id,
            model_arn,
            question,
            max_retries=5,
            wait_time=5
        )
        answers.append((question, answer))

    # Create the CSV file with the results
    output_key = generate_output_key(input_key)
    try:
        upload_csv_to_s3(s3_client, input_bucket, output_key, answers)
        logger.info(f"Successfully uploaded results to s3://{input_bucket}/{output_key}")
    except Exception as e:
        logger.error(f"Error uploading CSV to S3: {e}")
        return error_response(500, "Error uploading CSV file to S3.")

    return success_response(f"Processed {len(questions)} questions. Results saved to {output_key}")


# Helper Functions

def parse_s3_event(event):
    try:
        record = event["Records"][0]
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]
        return bucket, key
    except (KeyError, IndexError):
        raise ValueError("Malformed S3 event.")

def read_file_from_s3(s3_client, bucket, key):
    obj = s3_client.get_object(Bucket=bucket, Key=key)
    content = obj["Body"].read().decode("utf-8")
    return [line.strip() for line in content.splitlines() if line.strip()]

def generate_output_key(input_key):
    file_basename = os.path.splitext(os.path.basename(input_key))[0]
    timestamp = time.strftime("%Y%m%d-%H%M%S")
    return f"QuestionsAnswered/{file_basename}_answered_{timestamp}.csv"

def upload_csv_to_s3(s3_client, bucket, key, data):
    output_buffer = io.StringIO()
    csv_writer = csv.writer(output_buffer, quoting=csv.QUOTE_ALL)
    csv_writer.writerow(["Question", "Answer"])  # CSV header
    csv_writer.writerows(data)
    s3_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=output_buffer.getvalue().encode("utf-8")
    )

def call_bedrock_with_retries(client, knowledge_base_id, model_arn, question, max_retries=5, wait_time=5):
    prompt = (
        f"You are an expert in security compliance. Answer the following question using the provided "
        f"knowledge base. If the information is unavailable, respond with 'To be manually reviewed'.\n\n"
        f"Question: {question}"
    )

    for attempt in range(max_retries):
        try:
            logger.info(f"Calling Bedrock for question: '{question}' (Attempt {attempt + 1})")
            response = client.retrieve_and_generate(
                input={"text": prompt},
                retrieveAndGenerateConfiguration={
                    "type": "KNOWLEDGE_BASE",
                    "knowledgeBaseConfiguration": {
                        "knowledgeBaseId": knowledge_base_id,
                        "modelArn": model_arn
                    }
                }
            )
            return response["output"]["text"].strip()
        except Exception as e:
            logger.warning(f"Error on attempt {attempt + 1}: {e}")
            if attempt < max_retries - 1:
                time.sleep(wait_time)
            else:
                logger.error(f"Max retries reached for question: {question}")
                return "To be manually reviewed"

def error_response(status_code, message):
    return {"statusCode": status_code, "body": json.dumps({"error": message})}

def success_response(message):
    return {"statusCode": 200, "body": json.dumps({"message": message})}
