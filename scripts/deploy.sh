#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <environment> <stack-name|all> [additional aws deploy args...]" >&2
  exit 1
fi

ENVIRONMENT="$1"
TARGET_STACK="$2"
shift 2
EXTRA_ARGS=("$@")

PARAM_FILE="infra/env/${ENVIRONMENT}.parameters.json"
if [[ ! -f "${PARAM_FILE}" ]]; then
  echo "Parameter file not found: ${PARAM_FILE}" >&2
  exit 1
fi

STACK_ORDER=(
  "01-network-baseline"
  "02-stateful-services"
  "03-ingress-alb"
  "04-compute-ecs"
)

get_parameters() {
  local stack_name="$1"
  local params
  params=$(jq -r --arg stack "${stack_name}" '
    if has($stack) then
      .[$stack] | to_entries | map("\(.key)=\(.value)") | join(" ")
    else
      ""
    end
  ' "${PARAM_FILE}")
  echo "${params}"
}

deploy_stack() {
  local stack_name="$1"
  local template_path="infra/stacks/${stack_name}.yaml"
  if [[ ! -f "${template_path}" ]]; then
    echo "Template not found: ${template_path}" >&2
    exit 1
  fi

  local stack_id="librechat-${ENVIRONMENT}-${stack_name}"
  local params
  params=$(get_parameters "${stack_name}")

  echo "\nDeploying ${stack_id} from ${template_path}"
  if [[ -n "${params}" ]]; then
    aws cloudformation deploy \
      --stack-name "${stack_id}" \
      --template-file "${template_path}" \
      --capabilities CAPABILITY_NAMED_IAM \
      --parameter-overrides ${params} \
      "${EXTRA_ARGS[@]}"
  else
    aws cloudformation deploy \
      --stack-name "${stack_id}" \
      --template-file "${template_path}" \
      --capabilities CAPABILITY_NAMED_IAM \
      "${EXTRA_ARGS[@]}"
  fi
}

if [[ "${TARGET_STACK}" == "all" ]]; then
  for stack_name in "${STACK_ORDER[@]}"; do
    deploy_stack "${stack_name}"
  done
else
  deploy_stack "${TARGET_STACK}"
fi
