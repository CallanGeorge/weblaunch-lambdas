import {
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
} from 'aws-lambda';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, ScanCommand, GetCommand } from '@aws-sdk/lib-dynamodb';
import { corsGetHeaders } from '../utils/corsHeaders';

// Get configuration from environment variables
const region = process.env.AWS_REGION || 'eu-west-1';
const usersTableName = process.env.USERS_TABLE_NAME || 'WebLaunchUsers';

// Initialize DynamoDB client
const client = new DynamoDBClient({ region });
const dynamoDB = DynamoDBDocumentClient.from(client);

export interface BusinessDirectoryItem {
  id: string;
  businessName: string;
  businessDescription: string;
  businessType: string;
  contact: string;
  email: string;
  images?: string[];
  location: string;
  createdAt: string;
}

export class BusinessDirectoryService {
  /**
   * Get all businesses for the directory listing
   * Filters out private/sensitive data and only returns public-facing information
   */
  static async getAllBusinesses(): Promise<BusinessDirectoryItem[]> {
    const command = new ScanCommand({
      TableName: usersTableName,
      ProjectionExpression: 'id, businessName, businessDescription, businessType, contact, email, images, #location, createdAt',
      ExpressionAttributeNames: {
        '#location': 'location' // location is a reserved word in DynamoDB
      },
      FilterExpression: 'attribute_exists(businessName) AND businessName <> :empty',
      ExpressionAttributeValues: {
        ':empty': ''
      }
    });
    
    const result = await dynamoDB.send(command);
    
    if (!result.Items) {
      return [];
    }
    
    // Transform and clean the data for directory display
    return result.Items.map(item => ({
      id: item.id,
      businessName: item.businessName,
      businessDescription: item.businessDescription || '',
      businessType: item.businessType || 'Business',
      contact: item.contact || '',
      email: item.email || '',
      images: item.images || [],
      location: item.location || '',
      createdAt: item.createdAt || '',
    })) as BusinessDirectoryItem[];
  }

  /**
   * Get a specific business by ID for detailed view
   */
  static async getBusinessById(businessId: string): Promise<BusinessDirectoryItem | null> {
    const command = new GetCommand({
      TableName: usersTableName,
      Key: { id: businessId },
      ProjectionExpression: 'id, businessName, businessDescription, businessType, contact, email, images, #location, createdAt',
      ExpressionAttributeNames: {
        '#location': 'location'
      }
    });
    
    const result = await dynamoDB.send(command);
    
    if (!result.Item || !result.Item.businessName) {
      return null;
    }
    
    const item = result.Item;
    return {
      id: item.id,
      businessName: item.businessName,
      businessDescription: item.businessDescription || '',
      businessType: item.businessType || 'Business',
      contact: item.contact || '',
      email: item.email || '',
      images: item.images || [],
      location: item.location || '',
      createdAt: item.createdAt || '',
    } as BusinessDirectoryItem;
  }

  /**
   * Get businesses filtered by type
   */
  static async getBusinessesByType(businessType: string): Promise<BusinessDirectoryItem[]> {
    const command = new ScanCommand({
      TableName: usersTableName,
      ProjectionExpression: 'id, businessName, businessDescription, businessType, contact, email, images, #location, createdAt',
      ExpressionAttributeNames: {
        '#location': 'location'
      },
      FilterExpression: 'attribute_exists(businessName) AND businessName <> :empty AND businessType = :type',
      ExpressionAttributeValues: {
        ':empty': '',
        ':type': businessType
      }
    });
    
    const result = await dynamoDB.send(command);
    
    if (!result.Items) {
      return [];
    }
    
    return result.Items.map(item => ({
      id: item.id,
      businessName: item.businessName,
      businessDescription: item.businessDescription || '',
      businessType: item.businessType || 'Business',
      contact: item.contact || '',
      email: item.email || '',
      images: item.images || [],
      location: item.location || '',
      createdAt: item.createdAt || '',
    })) as BusinessDirectoryItem[];
  }
}

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  console.log('Processing business directory request:', JSON.stringify(event, null, 2));

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

  try {
    const path = event.path;
    const queryParams = event.queryStringParameters || {};

    // Handle different endpoints
    if (path === '/businesses' || path.endsWith('/businesses')) {
      // GET /businesses - Get all businesses or filter by type
      const businessType = queryParams.type;
      
      let businesses: BusinessDirectoryItem[];
      if (businessType) {
        businesses = await BusinessDirectoryService.getBusinessesByType(businessType);
      } else {
        businesses = await BusinessDirectoryService.getAllBusinesses();
      }

      return {
        statusCode: 200,
        headers: corsGetHeaders,
        body: JSON.stringify({ businesses }),
      };
    } else if (path.match(/\/businesses\/([^\/]+)$/)) {
      // GET /businesses/{id} - Get specific business
      const businessId = path.split('/').pop();
      if (!businessId) {
        return {
          statusCode: 400,
          headers: corsGetHeaders,
          body: JSON.stringify({ error: 'Business ID is required' }),
        };
      }

      const business = await BusinessDirectoryService.getBusinessById(businessId);
      if (!business) {
        return {
          statusCode: 404,
          headers: corsGetHeaders,
          body: JSON.stringify({ error: 'Business not found' }),
        };
      }

      return {
        statusCode: 200,
        headers: corsGetHeaders,
        body: JSON.stringify({ business }),
      };
    } else {
      return {
        statusCode: 404,
        headers: corsGetHeaders,
        body: JSON.stringify({ error: 'Endpoint not found' }),
      };
    }
  } catch (error: any) {
    console.error('❌ Error in business directory handler:', error);
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