import {
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
} from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, GetCommandInput } from '@aws-sdk/lib-dynamodb';
import { corsGetHeaders } from '../utils/corsHeaders';
import { AppointmentItem } from '../types/appointment';

// Get configuration from environment variables
const region = process.env.AWS_REGION || 'eu-west-1';
const tableName = process.env.TABLE_NAME || 'WebLaunchSchedulerAppointmentTable';
const environment = process.env.ENVIRONMENT || 'prod';

// Initialize DynamoDB client with environment-aware configuration
const client = new DynamoDBClient({ region });
const dynamoDB = DynamoDBDocumentClient.from(client);

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  console.log(`Processing request in ${environment} environment`);

  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsGetHeaders,
      body: JSON.stringify({ message: 'CORS preflight successful' }),
    };
  }

  if (event.httpMethod !== 'GET') {
    return {
      statusCode: 405,
      headers: corsGetHeaders,
      body: JSON.stringify({ error: 'Method not allowed' }),
    };
  }

  // Get parameters from query string
  const appointmentId = event.queryStringParameters?.appointmentId;
  const userId = event.queryStringParameters?.user;

  console.log('Query parameters:', event.queryStringParameters);
  console.log('Extracted appointmentId:', appointmentId);
  console.log('Extracted userId:', userId);

  if (!appointmentId || !userId) {
    return {
      statusCode: 400,
      headers: corsGetHeaders,
      body: JSON.stringify({ 
        error: 'Missing required query parameters: appointmentId and user',
        debug: {
          queryStringParameters: event.queryStringParameters,
          extractedIds: { appointmentId, userId }
        }
      }),
    };
  }

  const params: GetCommandInput = {
    TableName: tableName,
    Key: { appointmentId },
  };

  try {
    console.log('Getting appointment with ID:', appointmentId);
    const result = await dynamoDB.send(new GetCommand(params));

    if (!result.Item) {
      return {
        statusCode: 404,
        headers: corsGetHeaders,
        body: JSON.stringify({ error: 'Appointment not found' }),
      };
    }

    const item = result.Item as AppointmentItem;

    if (item.userId !== userId && item.personId !== userId) {
      return {
        statusCode: 403,
        headers: corsGetHeaders,
        body: JSON.stringify({
          error: 'Access denied. This appointment does not belong to the specified user.',
        }),
      };
    }

    return {
      statusCode: 200,
      headers: corsGetHeaders,
      body: JSON.stringify({ appointment: item }),
    };
  } catch (error: any) {
    console.error('❌ Error retrieving appointment:', error);
    return {
      statusCode: 500,
      headers: corsGetHeaders,
      body: JSON.stringify({
        error: 'Internal server error',
        details: error.message,
      }),
    };
  }
};