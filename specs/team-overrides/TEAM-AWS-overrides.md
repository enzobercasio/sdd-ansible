---
spec_id: TEAM-AWS-OVERRIDES
title: AWS Team Overrides
status: approved
version: "1.0"
owner: cloud-platform@company.com
applies_to_team: aws
created: 2026-05-21
last_reviewed: 2026-05-21
---

# AWS Team Overrides

> Applies to every spec with `team: aws`. Layers on top of `BEST-PRACTICES-SPEC.md`. When rules conflict, this document wins.

---

## §1 Intent

Capture AWS automation conventions once here so individual specs don't repeat them. These rules reflect Red Hat's and AWS's recommended practices for managing AWS infrastructure from AAP using the `amazon.aws` certified collection.

---

## §2 Additional Requirements

### Credentials & IAM

- **REQ-AWS-1**: AWS credentials (access keys, secret keys, session tokens) must **never** appear in playbooks, roles, defaults, or inventory. Credentials must be injected via AAP Amazon Web Services Credential type, which sets the standard `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` environment variables.
- **REQ-AWS-2**: IAM roles must be used wherever possible instead of IAM user access keys. EC2 instance profiles, ECS task roles, and Lambda execution roles eliminate long-lived credentials entirely. Document the required IAM role ARN and minimum permissions in the spec §4 Inputs.
- **REQ-AWS-3**: All IAM policies created or modified by automation must follow least privilege — grant only the permissions documented in the spec §3 Requirements. Wildcard (`*`) actions or resources in IAM policies require security team sign-off and documentation in the spec's Deviations table.
- **REQ-AWS-4**: Temporary credentials (STS AssumeRole) are preferred over permanent credentials for cross-account operations. Document the trust relationship and assumed role ARN in the spec.
- **REQ-AWS-5**: AWS Secrets Manager or HashiCorp Vault (via `community.hashi_vault`) must be used for application secrets on AWS. Do not store secrets in EC2 user data, environment variables baked into AMIs, or SSM Parameter Store plain text parameters.

### Resource Tagging

- **REQ-AWS-10**: Every AWS resource created by automation must be tagged at creation time. Required tags:

  | Tag | Value |
  |---|---|
  | `spec_id` | The automating spec's ID (e.g., `AUTO-2026-0042`) |
  | `managed_by` | `ansible` |
  | `team` | The owning team slug |
  | `environment` | `dev` / `staging` / `prod` |
  | `created_by` | The AAP job template name |

- **REQ-AWS-11**: Tags must be applied using the `tags:` parameter on the creating module, not as a separate tagging task. This ensures tags are present from the moment of resource creation.
- **REQ-AWS-12**: Existing resources must not have their required tags removed or modified by automation unless the spec explicitly calls for a tag update. Add a pre-flight check to verify tag state before modification.

### Resource Idempotency

- **REQ-AWS-20**: All AWS resource creation tasks must use `amazon.aws` modules that check existing state before acting. Modules in `amazon.aws` are idempotent by design when `state: present` is used — do not add redundant `when:` conditions that re-implement the idempotency check.
- **REQ-AWS-21**: Resource deletion tasks (`state: absent`) must include a pre-flight check confirming the resource exists and is not in a state that would make deletion unsafe (e.g., an RDS instance with deletion protection, an EC2 instance with termination protection).
- **REQ-AWS-22**: EC2 instance operations must target instances by tag or instance ID — never target by IP address, which can be reassigned after an instance is stopped.
- **REQ-AWS-23**: S3 bucket operations that modify ACLs or bucket policies must verify the intended ACL/policy state after the task completes, using `amazon.aws.s3_bucket_info` in a `verify` block.

### Networking & Security Groups

- **REQ-AWS-30**: Security group rules must be managed with `amazon.aws.ec2_security_group`. Do not manage security group rules by calling the AWS CLI via `ansible.builtin.command:`.
- **REQ-AWS-31**: Security group rules must specify CIDR ranges as precisely as possible. `0.0.0.0/0` ingress rules require security team sign-off and documentation in the spec.
- **REQ-AWS-32**: VPC and subnet IDs must be resolved from account/region/environment context at runtime using `amazon.aws.ec2_vpc_net_info` and `amazon.aws.ec2_vpc_subnet_info` — do not hardcode VPC or subnet IDs in role defaults. Hardcoded IDs break portability across environments.
- **REQ-AWS-33**: Route table and internet gateway modifications require `risk_tier: high` and CAB approval. Network path changes can cause production outages that are difficult to reverse quickly.

### Dynamic Inventory

- **REQ-AWS-40**: EC2 dynamic inventory must be used for any playbook that targets EC2 instances. Static inventory with hardcoded EC2 IPs is forbidden — IPs change on restart.
- **REQ-AWS-41**: Dynamic inventory filters must be scoped to the minimum necessary set of instances. The `filters:` key in the inventory source must include at minimum: `instance-state-name: running` and the `environment` tag matching the target environment.
- **REQ-AWS-42**: When using dynamic inventory in AAP, the inventory source must be refreshed before the job template runs. Configure the AAP inventory source to sync before each launch.

### State Management & Destructive Operations

- **REQ-AWS-50**: Tasks that terminate or delete AWS resources (`state: absent`, `terminate_instances:`) must be gated behind a variable that defaults to `false` — e.g., `aws_allow_termination: false`. The spec must document the expected behavior when this variable is set.
- **REQ-AWS-51**: EBS volume deletion must explicitly set `delete_on_termination:` to match the spec's intent. Do not rely on AMI launch defaults.
- **REQ-AWS-52**: RDS instance deletion must set `skip_final_snapshot: false` for `risk_tier: medium` and `risk_tier: high` — always create a final snapshot before deletion. Document the snapshot naming convention in the spec.
- **REQ-AWS-53**: Auto Scaling Group (ASG) operations must respect the current desired capacity and min/max bounds. Do not modify ASG capacity outside a scheduled maintenance window for `risk_tier: high` stacks.

### CloudFormation & Infrastructure as Code

- **REQ-AWS-60**: Ansible automation must not duplicate CloudFormation, Terraform, or CDK-managed infrastructure. If a resource is IaC-managed, Ansible may configure the application layer but must not modify the resource's attributes.
- **REQ-AWS-61**: Where `amazon.aws.cloudformation` is used, always set `on_create_failure: ROLLBACK` and `termination_protection: true` for production stacks.

---

## §3 Tooling Conventions

| Concern | Use this |
|---|---|
| EC2 instance management | `amazon.aws.ec2_instance` |
| S3 operations | `amazon.aws.s3_object`, `amazon.aws.s3_bucket` |
| IAM policies/roles | `amazon.aws.iam_policy`, `amazon.aws.iam_role` |
| Security groups | `amazon.aws.ec2_security_group` |
| VPC info | `amazon.aws.ec2_vpc_net_info`, `amazon.aws.ec2_vpc_subnet_info` |
| EC2 dynamic inventory | `amazon.aws.aws_ec2` inventory plugin |
| Secrets from Secrets Manager | `amazon.aws.aws_secret` lookup |
| SSM parameter (encrypted) | `community.aws.aws_ssm` lookup |
| CloudFormation | `amazon.aws.cloudformation` |
| Route 53 DNS | `amazon.aws.route53` |
| ELB / ALB | `amazon.aws.elb_application_lb` |
| RDS | `community.aws.rds_instance` |
| Lambda | `community.aws.lambda` |

---

## §4 Forbidden (in addition to universal list)

- ❌ Hardcoded AWS access keys or secret keys in any file
- ❌ Wildcard IAM permissions (`Action: "*"` or `Resource: "*"`) without security sign-off
- ❌ `0.0.0.0/0` ingress security group rules without security sign-off
- ❌ Static inventory with hardcoded EC2 IP addresses
- ❌ Hardcoded VPC IDs, subnet IDs, or AMI IDs in role defaults
- ❌ Targeting IaC-managed resources with state-changing Ansible tasks
- ❌ EC2 instance termination without a guard variable defaulting to `false`
- ❌ RDS deletion without a final snapshot for `risk_tier: medium/high`
- ❌ Using the `community.aws` collection instead of `amazon.aws` when `amazon.aws` provides the module

---

## §5 Required Collections

```yaml
collections:
  - name: amazon.aws
    version: ">=8.0.0"
  - name: community.aws
    version: ">=8.0.0"
```

Source: Red Hat Automation Hub. `amazon.aws` is a Red Hat Certified collection. `community.aws` is a community collection — use only for modules not yet present in `amazon.aws`.

---

## §6 Override Authority

Deviations from this document require:

1. Documentation in the spec's §7 Approvals → Deviations table.
2. Sign-off from the cloud platform team lead.
3. For IAM and networking deviations (REQ-AWS-3, REQ-AWS-31, REQ-AWS-33): additional sign-off from the security team.
4. For destructive resource operations (REQ-AWS-50 through REQ-AWS-53): CAB approval for `risk_tier: high`.

---

## §7 References

| Reference | URL |
|---|---|
| amazon.aws Collection Index | https://docs.ansible.com/ansible/latest/collections/amazon/aws/ |
| community.aws Collection Index | https://docs.ansible.com/ansible/latest/collections/community/aws/ |
| amazon.aws on Automation Hub | https://console.redhat.com/ansible/automation-hub/repo/published/amazon/aws/ |
| AAP Amazon Web Services Credential Type | https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/automation_controller_user_guide/controller-credentials |
| amazon.aws.ec2_instance Module | https://docs.ansible.com/ansible/latest/collections/amazon/aws/ec2_instance_module.html |
| amazon.aws.aws_ec2 Inventory Plugin | https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html |
| AWS IAM Best Practices | https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html |
| AWS Tagging Best Practices | https://docs.aws.amazon.com/tag-editor/latest/userguide/tagging.html |
| AWS Secrets Manager | https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html |
| Red Hat AAP on AWS | https://aws.amazon.com/solutions/partners/red-hat-ansible/ |
