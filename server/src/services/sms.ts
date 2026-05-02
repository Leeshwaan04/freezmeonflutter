import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';

const sns = new SNSClient({ region: process.env.AWS_REGION ?? 'eu-north-1' });

export async function sendSmsOtp(phoneNumber: string, code: string): Promise<void> {
  await sns.send(new PublishCommand({
    PhoneNumber: phoneNumber, // E.164 format e.g. +919876543210
    Message: `Your Freezme code is: ${code}. Valid for 10 minutes. Do not share this.`,
    MessageAttributes: {
      'AWS.SNS.SMS.SMSType': { DataType: 'String', StringValue: 'Transactional' },
      'AWS.SNS.SMS.SenderID': { DataType: 'String', StringValue: 'FREEZME' },
    },
  }));
}
