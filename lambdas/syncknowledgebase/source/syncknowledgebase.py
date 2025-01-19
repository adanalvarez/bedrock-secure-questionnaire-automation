import boto3
import json
import os
import time
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
KNOWLEDGE_BASE_ID = os.environ.get("KNOWLEDGE_BASE_ID")
DATA_SOURCE_ID = os.environ.get("DATA_SOURCE_ID")
REGION_NAME = os.environ.get("REGION_NAME", "us-east-1")

# Retry constants
MAX_RETRIES = 5
INITIAL_RETRY_DELAY = 5  # in seconds

def lambda_handler(event, context):
    """
    AWS Lambda function to start an ingestion job for a knowledge base in Amazon Bedrock with retries.
    """
    try:
        # Validate required environment variables
        validate_environment_variables()
        
        # Initialize Bedrock client
        client = boto3.client("bedrock-agent", region_name=REGION_NAME)

        # Start ingestion job with retry logic
        response = start_ingestion_job_with_retries(client, KNOWLEDGE_BASE_ID, DATA_SOURCE_ID)
        
        # Success response
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Ingestion job started successfully",
                "jobId": response["ingestionJob"]["ingestionJobId"]
            })
        }
    except ValueError as ve:
        logger.error(f"Validation error: {ve}")
        return error_response(400, str(ve))
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return error_response(500, str(e))


# Helper Functions

def validate_environment_variables():
    """Ensure required environment variables are set."""
    if not KNOWLEDGE_BASE_ID:
        raise ValueError("KNOWLEDGE_BASE_ID environment variable is not set.")
    if not DATA_SOURCE_ID:
        raise ValueError("DATA_SOURCE_ID environment variable is not set.")
    if not REGION_NAME:
        raise ValueError("REGION_NAME environment variable is not set.")

def start_ingestion_job_with_retries(client, knowledge_base_id, data_source_id):
    """
    Attempt to start the ingestion job with retries in case of transient errors.
    """
    retries = 0
    while retries < MAX_RETRIES:
        try:
            logger.info(f"Starting ingestion job for KnowledgeBaseId: {knowledge_base_id}, DataSourceId: {data_source_id}")
            return client.start_ingestion_job(
                knowledgeBaseId=knowledge_base_id,
                dataSourceId=data_source_id
            )
        except Exception as e:
            # Handle transient errors with retries
            if retries < MAX_RETRIES - 1:
                wait_time = INITIAL_RETRY_DELAY * (2 ** retries)
                logger.warning(f"Error starting ingestion job: {e}. Retrying in {wait_time} seconds... (Attempt {retries + 1}/{MAX_RETRIES})")
                time.sleep(wait_time)
                retries += 1
            else:
                logger.error("Max retries reached. Unable to start ingestion job.")
                raise e
    raise RuntimeError("Max retries reached. Unable to start ingestion job.")

def error_response(status_code, message):
    """Construct an error response."""
    return {
        "statusCode": status_code,
        "body": json.dumps({"error": message})
    }
