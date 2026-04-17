#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=validate.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/validate.sh"
# shellcheck source=deploy.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/deploy.sh"
# shellcheck source=repos.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/repos.sh"
# shellcheck source=materialize.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/materialize.sh"
# shellcheck source=metadata.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/metadata.sh"
# shellcheck source=verify.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/verify.sh"

run_full_prepare_pipeline() {
  section "Full prepare pipeline"
  validate_session_inputs
  run_deploy_skeleton
  materialize_source_repos
  materialize_install_bundles
  write_install_metadata
  run_verify_skeleton
  ok "Full prepare pipeline completed"
}
