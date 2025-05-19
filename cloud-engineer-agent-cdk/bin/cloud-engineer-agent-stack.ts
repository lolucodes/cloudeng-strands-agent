#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { CloudEngineerAgentStack } from '../lib/cloud-engineer-agent-stack';

const app = new cdk.App();
new CloudEngineerAgentStack(app, 'CloudEngineerAgentStack', {
  env: { 
    account: process.env.CDK_DEFAULT_ACCOUNT, 
    region: process.env.CDK_DEFAULT_REGION || 'us-east-1'
  },
});
