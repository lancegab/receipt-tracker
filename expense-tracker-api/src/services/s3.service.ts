import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { v4 as uuidv4 } from 'uuid';

const s3Client = new S3Client({
  region: process.env.AWS_REGION || 'us-east-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
});

const BUCKET = process.env.S3_BUCKET!;
const PRESIGNED_EXPIRES = parseInt(process.env.S3_PRESIGNED_EXPIRES || '300');

export async function getPresignedUploadUrl(
  userId: string,
  filename: string,
  contentType: string
): Promise<{ uploadUrl: string; s3Key: string; expiresIn: number }> {
  const ext = filename.split('.').pop() || 'jpg';
  const s3Key = `receipts/${userId}/${uuidv4()}.${ext}`;

  const command = new PutObjectCommand({
    Bucket: BUCKET,
    Key: s3Key,
    ContentType: contentType,
  });

  const uploadUrl = await getSignedUrl(s3Client, command, {
    expiresIn: PRESIGNED_EXPIRES,
  });

  return { uploadUrl, s3Key, expiresIn: PRESIGNED_EXPIRES };
}

export async function getPresignedViewUrl(s3Key: string): Promise<string> {
  const command = new GetObjectCommand({
    Bucket: BUCKET,
    Key: s3Key,
  });

  return getSignedUrl(s3Client, command, { expiresIn: 3600 });
}

export async function getObjectBuffer(s3Key: string): Promise<Buffer> {
  const command = new GetObjectCommand({
    Bucket: BUCKET,
    Key: s3Key,
  });

  const response = await s3Client.send(command);
  const stream = response.Body;

  if (!stream) throw new Error('Empty response from S3');

  const chunks: Uint8Array[] = [];
  for await (const chunk of stream as AsyncIterable<Uint8Array>) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

export async function deleteObject(s3Key: string): Promise<void> {
  const command = new DeleteObjectCommand({
    Bucket: BUCKET,
    Key: s3Key,
  });

  await s3Client.send(command);
}
