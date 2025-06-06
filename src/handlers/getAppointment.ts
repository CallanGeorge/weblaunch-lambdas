import {
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
} from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, GetCommandInput } from '@aws-sdk/lib-dynamodb';
import { corsGetHeaders } from '../utils/corsHeaders';
import { AppointmentItem } from '../types/appointment';

// Initialize DynamoDB client with AWS SDK v3
const client = new DynamoDBClient({ region: 'eu-west-1' });
const dynamoDB = DynamoDBDocumentClient.from(client);
const tableName = 'WebLaunchSchedulerAppointmentTable';

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
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

  // Parse path parameters from the proxy path
  // Path will be like: /appointment/BOOKING-mbgvx3oc-ctetcdw3/user/52957424-f0d1-7050-1be4-2ec097c19379
  const pathMatch = event.path.match(/\/appointment\/([^\/]+)\/user\/([^\/]+)/);
  
  const appointmentId = pathMatch?.[1] || 
    event.pathParameters?.appointmentId ||
    event.queryStringParameters?.appointmentId;

  const userId = pathMatch?.[2] ||
    event.pathParameters?.userId ||
    event.queryStringParameters?.userId;

  console.log('Event path:', event.path);
  console.log('Path match result:', pathMatch);
  console.log('Extracted appointmentId:', appointmentId);
  console.log('Extracted userId:', userId);

  if (!appointmentId || !userId) {
    return {
      statusCode: 400,
      headers: corsGetHeaders,
      body: JSON.stringify({ 
        error: 'Missing appointmentId or userId parameter',
        debug: {
          path: event.path,
          pathParameters: event.pathParameters,
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