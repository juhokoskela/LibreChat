# LibreChat Infrastructure (Simplified Stacks)

This directory contains a small set of CloudFormation templates that keep the AWS footprint for LibreChat easy to reason about. Each stack owns a clearly defined responsibility and stays under ~150 lines so updates are straightforward to review.

## Directory Layout

```
infra/
  README.md
  env/
    dev.parameters.json     # Example parameters for a dev workspace
    prod.parameters.json    # Example parameters for production
  stacks/
    01-network-baseline.yaml   # VPC, public subnets, and security groups
    02-stateful-services.yaml  # S3 bucket + Secrets Manager anchors
    03-ingress-alb.yaml        # Internet-facing ALB with HTTPS redirect
    04-compute-ecs.yaml        # Single ECS service hosting LibreChat + addons
scripts/
  deploy.sh                   # Helper wrapper around aws cloudformation deploy
```

The `deploy.sh` helper expects `jq` and the AWS CLI v2. It converts the JSON files in `infra/env/` into `--parameter-overrides` flags and applies the stacks in dependency order.

### Deploying

Deploy one stack at a time:

```
scripts/deploy.sh dev 03-ingress-alb --tags env=dev app=librechat
```

Or run the complete sequence:

```
scripts/deploy.sh prod all --tags env=prod app=librechat
```

Before deploying, update `infra/env/<environment>.parameters.json` with the correct identifiers (certificate ARN, secret ARNs, etc.). Empty strings are placeholders and should be replaced.

## Stack Overview

1. **01-network-baseline** – Creates a new VPC with two public subnets, internet gateway, and security groups for the ALB and ECS tasks. Tasks run in public subnets to avoid NAT Gateways while still restricting ingress via the ALB security group.
2. **02-stateful-services** – Provisions a versioned, TLS-enforced S3 bucket (retained on stack deletion) plus Secrets Manager entries for MongoDB, Redis, rag_service, and the MCP adapters. Populate these secrets with real values before deploying compute.
3. **03-ingress-alb** – Builds an internet-facing Application Load Balancer, target group, and HTTP→HTTPS redirect listener. Supply a validated ACM certificate ARN (same region/account) via parameters.
4. **04-compute-ecs** – Spins up a single ECS Fargate service that runs the LibreChat container alongside rag_service and any MCP servers you enable. The containers share a task so they can communicate over `localhost`, which keeps networking trivial.

All stacks export their key outputs using the `${StackName}:OutputName` convention so later stacks can reference them via `Fn::ImportValue` or parameter files.

## RAG and MCP Services

The compute stack enables rag_service and each MCP server through toggle parameters (`EnableRagService`, `EnableSlackMcp`, etc.). When a toggle is set to `true`, provide the matching Secrets Manager ARN so the task can pull credentials at runtime. The sample parameter files illustrate the minimum required fields.

Because every container runs inside the same ECS task:

- LibreChat reaches rag_service at `http://localhost:8000` and authenticates with the generated `RAG_API_TOKEN` secret.
- MCP servers expose their SSE endpoints on unique ports bound to `localhost`. Reference them inside `librechat.yaml` accordingly.
- Scaling happens at the task level—update `DesiredCount`, `TaskCpu`, or `TaskMemory` if the combined containers need more capacity.

## Secrets and Configuration

Stateful resources all have `DeletionPolicy: Retain` so accidental stack deletes do not wipe data. After deploying `02-stateful-services`, update each secret with production credentials:

- `MongoConnectionSecret`: set the Atlas/DocumentDB connection string at key `uri`.
- `RedisConnectionSecret`: optional Redis URI for LibreChat caching.
- `RagPostgresSecret` and `RagRedisSecret`: host/user/password for the databases powering rag_service.
- `RagApiTokenSecret`: token that both LibreChat and rag_service share.
- MCP secrets: provide the API tokens and endpoints for Slack, Atlassian, and Pipedrive as needed.

Other provider keys (OpenAI, Jina, etc.) can be stored in Secrets Manager as well—extend the task definition with additional `Secrets` entries when required.

## Testing Checklist

- `curl -I https://<domain>` returns `200` after following the HTTPS redirect.
- ECS deployments with a bad image trigger the circuit breaker and roll back automatically.
- Rotating any Secrets Manager value and re-deploying updates credentials without code changes.
- Non-TLS S3 requests are denied due to the enforced bucket policy.
- LibreChat successfully reaches rag_service and the enabled MCP endpoints over `localhost`.

Document the results of these checks for each environment so regressions are easy to trace.
