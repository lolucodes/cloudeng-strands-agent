import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecr from 'aws-cdk-lib/aws-ecr';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as ecr_assets from 'aws-cdk-lib/aws-ecr-assets';
import * as ecr_deployment from 'cdk-ecr-deployment';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import { Construct } from 'constructs';

export class CloudEngineerAgentStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create a VPC with only public subnets (no NAT Gateway)
    const vpc = new ec2.Vpc(this, 'CloudEngineerAgentVPC', {
      maxAzs: 2,
      subnetConfiguration: [
        {
          cidrMask: 24,
          name: 'public',
          subnetType: ec2.SubnetType.PUBLIC,
        }
      ],
      natGateways: 0, // No NAT Gateway as requested
    });

    // Create an ECR repository for the agent
    const agentRepo = new ecr.Repository(this, 'CloudEngineerAgentRepo', {
      repositoryName: 'cloud-engineer-agent',
      removalPolicy: cdk.RemovalPolicy.DESTROY, // For demo purposes only
      imageScanOnPush: true,
      emptyOnDelete: true,
    });

    // Build the Docker image
    const agentImageAsset = new ecr_assets.DockerImageAsset(this, 'CloudEngineerAgentImage', {
      directory: '../', // Path to the directory containing Dockerfile
      exclude: ['cdk.out', 'cloud-engineer-agent-cdk', 'node_modules', '.git'],
      platform: ecr_assets.Platform.LINUX_AMD64
    });

    // Deploy the Docker image to ECR using cdk-ecr-deployment
    new ecr_deployment.ECRDeployment(this, 'DeployCloudEngineerAgentImage', {
      src: new ecr_deployment.DockerImageName(agentImageAsset.imageUri),
      dest: new ecr_deployment.DockerImageName(agentRepo.repositoryUri + ':latest'),
    });

    // Create ECS cluster
    const cluster = new ecs.Cluster(this, 'CloudEngineerAgentCluster', {
      vpc: vpc,
    });

    // Create IAM role for the ECS task
    const taskRole = new iam.Role(this, 'CloudEngineerAgentTaskRole', {
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
    });

    // Add AWS permissions needed for the agent
    taskRole.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('ReadOnlyAccess'));
    
    // Add Bedrock permissions for the agent
    taskRole.addToPolicy(new iam.PolicyStatement({
      actions: [
        'bedrock:InvokeModel',
        'bedrock:InvokeModelWithResponseStream'
      ],
      resources: ['*'],
    }));

    // Create ECS task definition
    const taskDefinition = new ecs.FargateTaskDefinition(this, 'CloudEngineerAgentTaskDef', {
      memoryLimitMiB: 2048,
      cpu: 1024,
      taskRole: taskRole,
    });

    // Add container to the task definition
    const container = taskDefinition.addContainer('CloudEngineerAgentContainer', {
      image: ecs.ContainerImage.fromEcrRepository(agentRepo, 'latest'),
      logging: ecs.LogDrivers.awsLogs({ streamPrefix: 'cloud-engineer-agent' }),
      environment: {
        'AWS_REGION': this.region,
      },
    });

    // Add port mapping
    container.addPortMappings({
      containerPort: 8501,
      hostPort: 8501,
      protocol: ecs.Protocol.TCP,
    });

    // Create security group for the service
    const securityGroup = new ec2.SecurityGroup(this, 'CloudEngineerAgentSG', {
      vpc,
      description: 'Allow access to the Cloud Engineer Agent',
      allowAllOutbound: true,
    });

    // Allow inbound traffic on port 8501 (Streamlit)
    securityGroup.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(8501),
      'Allow Streamlit traffic'
    );

    // Create ECS service with a load balancer
    const service = new ecs.FargateService(this, 'CloudEngineerAgentService', {
      cluster,
      taskDefinition,
      desiredCount: 1,
      assignPublicIp: true, // Required for public subnet without NAT
      vpcSubnets: { subnetType: ec2.SubnetType.PUBLIC },
      securityGroups: [securityGroup]
    });
    
    // Create load balancer
    const loadBalancer = new elbv2.ApplicationLoadBalancer(this, 'CloudEngineerAgentLB', {
      vpc,
      internetFacing: true
    });
    
    const listener = loadBalancer.addListener('Listener', {
      port: 80,
    });
    
    const targetGroup = listener.addTargets('ECS', {
      port: 8501,
      protocol: elbv2.ApplicationProtocol.HTTP,
      targets: [service.loadBalancerTarget({
        containerName: 'CloudEngineerAgentContainer',
        containerPort: 8501
      })],
      healthCheck: {
        path: '/',
        interval: cdk.Duration.seconds(60),
        timeout: cdk.Duration.seconds(5),
      }
    });
    
    // Output the public URL
    new cdk.CfnOutput(this, 'CloudEngineerAgentURL', {
      value: `http://${loadBalancer.loadBalancerDnsName}`,
      description: 'URL for the Cloud Engineer Agent',
    });

    // Output the ECR repository URI
    new cdk.CfnOutput(this, 'CloudEngineerAgentRepoURI', {
      value: agentRepo.repositoryUri,
      description: 'ECR Repository URI',
    });
  }
}
