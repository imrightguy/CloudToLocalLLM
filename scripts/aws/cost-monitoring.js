#!/usr/bin/env node

/**
 * AWS Cost Monitoring and Reporting
 *
 * Monitors AWS EKS cluster costs and generates reports
 * Integrates with AWS Cost Explorer and CloudWatch
 * 
 * Migrated to AWS SDK v3
 */

const { CostExplorerClient, GetCostAndUsageCommand } = require('@aws-sdk/client-cost-explorer');
const { CloudWatchClient, PutDashboardCommand, PutMetricAlarmCommand } = require('@aws-sdk/client-cloudwatch');
const fs = require('fs');
const path = require('path');

const AWS_ACCOUNT_ID = '422017356244';
const AWS_REGION = 'us-east-1';
const CLUSTER_NAME = 'zoidbot-eks';

// Initialize AWS SDK v3 clients
const costExplorerClient = new CostExplorerClient({ region: AWS_REGION });
const cloudwatchClient = new CloudWatchClient({ region: AWS_REGION });

/**
 * Cost estimation data for common resources
 */
const COST_ESTIMATES = {
  't3.small': {
    hourly: 0.0208,
    monthly: 15.36,
    description: 't3.small EC2 instance',
  },
  't3.medium': {
    hourly: 0.0416,
    monthly: 30.72,
    description: 't3.medium EC2 instance',
  },
  't3.micro': {
    hourly: 0.0104,
    monthly: 7.68,
    description: 't3.micro EC2 instance',
  },
  'network-load-balancer': {
    hourly: 0.0225,
    monthly: 16.56,
    description: 'Network Load Balancer',
  },
  'ebs-storage': {
    perGb: 0.10,
    monthly: 10,
    description: 'EBS storage (100GB estimate)',
  },
  'data-transfer': {
    perGb: 0.02,
    monthly: 5,
    description: 'Data transfer out (250GB estimate)',
  },
  'cloudwatch-logs': {
    perGb: 0.50,
    monthly: 5,
    description: 'CloudWatch logs (10GB estimate)',
  },
};

/**
 * Get cost and usage data from AWS Cost Explorer
 */
async function getCostAndUsageData(startDate, endDate) {
  try {
    const command = new GetCostAndUsageCommand({
      TimePeriod: {
        Start: startDate,
        End: endDate,
      },
      Granularity: 'DAILY',
      Metrics: ['UnblendedCost'],
      GroupBy: [
        {
          Type: 'DIMENSION',
          Key: 'SERVICE',
        },
      ],
      Filter: {
        Tags: {
          Key: 'Environment',
          Values: ['development'],
        },
      },
    });

    const response = await costExplorerClient.send(command);
    return response;
  } catch (error) {
    console.error('Error fetching cost data:', error);
    throw error;
  }
}

/**
 * Calculate estimated monthly cost for cluster configuration
 */
function calculateEstimatedMonthlyCost(config) {
  let totalCost = 0;
  const breakdown = {};

  // EC2 instance costs
  if (config.nodeInstanceType && COST_ESTIMATES[config.nodeInstanceType]) {
    const instanceCost = COST_ESTIMATES[config.nodeInstanceType].monthly * config.desiredNodes;
    breakdown[config.nodeInstanceType] = {
      cost: instanceCost,
      description: `${config.desiredNodes}x ${COST_ESTIMATES[config.nodeInstanceType].description}`,
    };
    totalCost += instanceCost;
  }

  // Network Load Balancer
  if (config.enableLoadBalancer !== false) {
    const nlbCost = COST_ESTIMATES['network-load-balancer'].monthly;
    breakdown['network-load-balancer'] = {
      cost: nlbCost,
      description: COST_ESTIMATES['network-load-balancer'].description,
    };
    totalCost += nlbCost;
  }

  // EBS storage
  if (config.enableStorage !== false) {
    const storageCost = COST_ESTIMATES['ebs-storage'].monthly;
    breakdown['ebs-storage'] = {
      cost: storageCost,
      description: COST_ESTIMATES['ebs-storage'].description,
    };
    totalCost += storageCost;
  }

  // Data transfer
  if (config.enableDataTransfer !== false) {
    const transferCost = COST_ESTIMATES['data-transfer'].monthly;
    breakdown['data-transfer'] = {
      cost: transferCost,
      description: COST_ESTIMATES['data-transfer'].description,
    };
    totalCost += transferCost;
  }

  // CloudWatch logs
  if (config.enableLogging !== false) {
    const logsCost = COST_ESTIMATES['cloudwatch-logs'].monthly;
    breakdown['cloudwatch-logs'] = {
      cost: logsCost,
      description: COST_ESTIMATES['cloudwatch-logs'].description,
    };
    totalCost += logsCost;
  }

  return {
    totalCost: parseFloat(totalCost.toFixed(2)),
    breakdown,
  };
}

/**
 * Create CloudWatch dashboard for cost tracking
 */
async function createCostDashboard() {
  try {
    const dashboardBody = {
      widgets: [
        {
          type: 'metric',
          properties: {
            metrics: [
              ['AWS/EC2', 'CPUUtilization', { stat: 'Average' }],
              ['AWS/ELB', 'TargetResponseTime', { stat: 'Average' }],
              ['AWS/ECS', 'MemoryUtilization', { stat: 'Average' }],
            ],
            period: 300,
            stat: 'Average',
            region: AWS_REGION,
            title: 'EKS Cluster Performance',
          },
        },
        {
          type: 'metric',
          properties: {
            metrics: [
              ['AWS/Billing', 'EstimatedCharges', { stat: 'Maximum' }],
            ],
            period: 86400,
            stat: 'Maximum',
            region: 'us-east-1',
            title: 'Estimated Daily Charges',
          },
        },
      ],
    };

    const command = new PutDashboardCommand({
      DashboardName: `${CLUSTER_NAME}-cost-tracking`,
      DashboardBody: JSON.stringify(dashboardBody),
    });

    const response = await cloudwatchClient.send(command);
    return response;
  } catch (error) {
    console.error('Error creating CloudWatch dashboard:', error);
    throw error;
  }
}

/**
 * Configure monthly cost alerts
 */
async function configureCostAlerts(monthlyBudget) {
  try {
    const command = new PutMetricAlarmCommand({
      AlarmName: `${CLUSTER_NAME}-monthly-cost-alert`,
      ComparisonOperator: 'GreaterThanThreshold',
      EvaluationPeriods: 1,
      MetricName: 'EstimatedCharges',
      Namespace: 'AWS/Billing',
      Period: 86400,
      Statistic: 'Maximum',
      Threshold: monthlyBudget,
      ActionsEnabled: true,
      AlarmDescription: `Alert when monthly AWS costs exceed ${monthlyBudget}`,
      Dimensions: [
        {
          Name: 'Currency',
          Value: 'USD',
        },
      ],
    });

    const response = await cloudwatchClient.send(command);
    return response;
  } catch (error) {
    console.error('Error configuring cost alerts:', error);
    throw error;
  }
}

/**
 * Generate cost optimization report
 */
function generateCostOptimizationReport(config, estimatedCost) {
  const report = {
    timestamp: new Date().toISOString(),
    clusterName: CLUSTER_NAME,
    awsAccountId: AWS_ACCOUNT_ID,
    awsRegion: AWS_REGION,
    configuration: {
      nodeInstanceType: config.nodeInstanceType,
      desiredNodes: config.desiredNodes,
      minNodes: config.minNodes,
      maxNodes: config.maxNodes,
      kubernetesVersion: config.kubernetesVersion,
    },
    costAnalysis: {
      estimatedMonthlyCost: estimatedCost.totalCost,
      breakdown: estimatedCost.breakdown,
      budget: 300,
      budgetUtilization: `${((estimatedCost.totalCost / 300) * 100).toFixed(2)}%`,
      withinBudget: estimatedCost.totalCost <= 300,
    },
    recommendations: generateRecommendations(config, estimatedCost),
  };

  return report;
}

/**
 * Generate cost optimization recommendations
 */
function generateRecommendations(config, estimatedCost) {
  const recommendations = [];

  // Check instance type
  if (config.nodeInstanceType === 't3.medium') {
    recommendations.push({
      priority: 'high',
      recommendation: 'Consider using t3.small or t3.micro for development to reduce costs',
      potentialSavings: (COST_ESTIMATES['t3.medium'].monthly - COST_ESTIMATES['t3.small'].monthly) * config.desiredNodes,
    });
  }

  // Check node count
  if (config.desiredNodes > 2) {
    recommendations.push({
      priority: 'medium',
      recommendation: 'Consider reducing desired nodes to 2 for development',
      potentialSavings: COST_ESTIMATES[config.nodeInstanceType].monthly,
    });
  }

  // Check if over budget
  if (estimatedCost.totalCost > 300) {
    recommendations.push({
      priority: 'critical',
      recommendation: 'Cluster cost exceeds budget. Immediate action required.',
      potentialSavings: estimatedCost.totalCost - 300,
    });
  }

  // Check if under-utilized
  if (estimatedCost.totalCost < 50) {
    recommendations.push({
      priority: 'low',
      recommendation: 'Cluster is well-optimized for cost',
      potentialSavings: 0,
    });
  }

  return recommendations;
}

/**
 * Export cost report to file
 */
function exportCostReport(report, outputPath) {
  try {
    const reportPath = path.join(outputPath, `cost-report-${Date.now()}.json`);
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
    return reportPath;
  } catch (error) {
    console.error('Error exporting cost report:', error);
    throw error;
  }
}

/**
 * Main function
 */
async function main() {
  try {
    // Example cluster configuration
    const clusterConfig = {
      nodeInstanceType: 't3.small',
      desiredNodes: 2,
      minNodes: 2,
      maxNodes: 3,
      kubernetesVersion: '1.28',
      enableLoadBalancer: true,
      enableStorage: true,
      enableDataTransfer: true,
      enableLogging: true,
    };

    // Calculate estimated cost
    const estimatedCost = calculateEstimatedMonthlyCost(clusterConfig);

    // Generate report
    const report = generateCostOptimizationReport(clusterConfig, estimatedCost);

    // Export report
    const reportPath = exportCostReport(report, './docs');

    console.log('Cost Monitoring Report Generated:');
    console.log(JSON.stringify(report, null, 2));
    console.log(`\nReport saved to: ${reportPath}`);

    return report;
  } catch (error) {
    console.error('Error in cost monitoring:', error);
    process.exit(1);
  }
}

// Export functions for testing
module.exports = {
  calculateEstimatedMonthlyCost,
  generateCostOptimizationReport,
  generateRecommendations,
  exportCostReport,
  createCostDashboard,
  configureCostAlerts,
  getCostAndUsageData,
  COST_ESTIMATES,
};

// Run if executed directly
if (require.main === module) {
  main();
}
