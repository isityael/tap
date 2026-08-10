#!/usr/bin/env bash
# Publish a built fast-cli bottle from canonical Forgejo state to both forges.

set -euo pipefail

required_environment=(
  VERSION
  BOTTLE_FILE
  BOTTLE_JSON
  EXPECTED_COMMIT
  FORGEJO_TOKEN
  GITHUB_TOKEN
)

for variable in "${required_environment[@]}"
do
  if [[ -z "${!variable:-}" ]]
  then
    echo "required environment variable is missing: ${variable}" >&2
    exit 1
  fi
done

for command in curl fj gh git jq
do
  if ! command -v "${command}" >/dev/null 2>&1
  then
    echo "required command is missing: ${command}" >&2
    exit 1
  fi
done

if [[ ! -f "${BOTTLE_FILE}" || ! -f "${BOTTLE_JSON}" ]]
then
  echo "bottle file or bottle JSON is missing" >&2
  exit 1
fi

if [[ ! -f Formula/fast-cli.rb ]]
then
  echo "Formula/fast-cli.rb is missing" >&2
  exit 1
fi

FORGEJO_REPO_URL="https://git.m0sh1.cc/isityael/tap.git"
FORGEJO_API="https://git.m0sh1.cc/api/v1"
FORGEJO_REPO="isityael/tap"
GITHUB_REPO="isityael/tap"
TAG="fast-cli-${VERSION}"
ASSET_NAME=$(basename "${BOTTLE_FILE}")
TMP_DIR=$(mktemp -d)

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1
  then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

remote_tag_commit() {
  local url=$1
  git ls-remote "${url}" "refs/tags/${TAG}^{}" "refs/tags/${TAG}" |
    awk 'NR == 1 {print $1}'
}

fetch_api_json() {
  local destination=$1
  local authorization=$2
  local url=$3
  local status

  status=$(curl -sS -o "${destination}" -w '%{http_code}' \
    -H "${authorization}" "${url}")
  case "${status}" in
    200)
      return 0
      ;;
    404)
      return 1
      ;;
    *)
      echo "API request failed with HTTP ${status}: ${url}" >&2
      exit 1
      ;;
  esac
}

verify_release_asset() {
  local platform=$1
  local release_json=$2
  local authorization=$3
  local expected_size
  local expected_sha
  local asset_url
  local asset_size
  local downloaded_file="${TMP_DIR}/${platform}-${ASSET_NAME}"

  expected_size=$(wc -c < "${BOTTLE_FILE}" | tr -d ' ')
  expected_sha=$(sha256_file "${BOTTLE_FILE}")
  asset_url=$(jq -r --arg name "${ASSET_NAME}" \
    '.assets[] | select(.name == $name) | .browser_download_url' \
    "${release_json}" | head -n 1)
  asset_size=$(jq -r --arg name "${ASSET_NAME}" \
    '.assets[] | select(.name == $name) | .size' \
    "${release_json}" | head -n 1)

  if [[ -z "${asset_url}" || "${asset_url}" == "null" ]]
  then
    return 1
  fi

  if [[ "${asset_size}" != "${expected_size}" ]]
  then
    echo "${platform} release asset size differs for ${ASSET_NAME}" >&2
    exit 1
  fi

  curl -fsSL -H "${authorization}" -o "${downloaded_file}" "${asset_url}"
  if [[ "$(sha256_file "${downloaded_file}")" != "${expected_sha}" ]]
  then
    echo "${platform} release asset digest differs for ${ASSET_NAME}" >&2
    exit 1
  fi

  echo "verified ${platform} release asset ${ASSET_NAME}"
}

initial_commit=$(git rev-parse HEAD)
if [[ "${initial_commit}" != "${EXPECTED_COMMIT}" ]]
then
  echo "workspace commit ${initial_commit} does not match expected ${EXPECTED_COMMIT}" >&2
  exit 1
fi

git remote set-url origin "${FORGEJO_REPO_URL}"
existing_tag_commit=$(remote_tag_commit "${FORGEJO_REPO_URL}")

if [[ -n "${existing_tag_commit}" ]]
then
  git fetch --quiet origin "refs/tags/${TAG}:refs/tags/${TAG}"
  git show "${existing_tag_commit}:Formula/fast-cli.rb" > "${TMP_DIR}/remote-formula.rb"
  if ! cmp -s Formula/fast-cli.rb "${TMP_DIR}/remote-formula.rb"
  then
    echo "existing tag ${TAG} points at different formula content" >&2
    exit 1
  fi
  release_commit=${existing_tag_commit}
else
  if git diff --quiet -- Formula/fast-cli.rb
  then
    echo "generated fast-cli formula has no changes" >&2
    exit 1
  fi

  git config user.name "Woodpecker CI"
  git config user.email "ci@m0sh1.cc"
  git add Formula/fast-cli.rb
  git commit -m "fast-cli: add bottle block for ${VERSION} [CI SKIP]"
  release_commit=$(git rev-parse HEAD)
  git tag "${TAG}" "${release_commit}"

  forgejo_auth=$(printf '%s' "isityael:${FORGEJO_TOKEN}" | base64 | tr -d '\n')
  git -c http.extraHeader="Authorization: Basic ${forgejo_auth}" \
    push origin HEAD:main "refs/tags/${TAG}"
  unset forgejo_auth
fi

forgejo_tag_commit=$(remote_tag_commit "${FORGEJO_REPO_URL}")
if [[ "${forgejo_tag_commit}" != "${release_commit}" ]]
then
  echo "Forgejo tag ${TAG} does not resolve to ${release_commit}" >&2
  exit 1
fi

deadline=$((SECONDS + 120))
github_tag_commit=""
while ((SECONDS < deadline))
do
  github_tag_commit=$(remote_tag_commit "https://github.com/${GITHUB_REPO}.git")
  if [[ "${github_tag_commit}" == "${release_commit}" ]]
  then
    break
  fi
  sleep 5
done

if [[ "${github_tag_commit}" != "${release_commit}" ]]
then
  echo "mirror deadline exceeded waiting for GitHub tag ${TAG}" >&2
  exit 1
fi

printf '%s' "${FORGEJO_TOKEN}" | fj auth add-token -H git.m0sh1.cc >/dev/null

forgejo_release_json="${TMP_DIR}/forgejo-release.json"
if fetch_api_json "${forgejo_release_json}" \
  "Authorization: token ${FORGEJO_TOKEN}" \
  "${FORGEJO_API}/repos/${FORGEJO_REPO}/releases/tags/${TAG}"
then
  if ! verify_release_asset forgejo "${forgejo_release_json}" \
    "Authorization: token ${FORGEJO_TOKEN}"
  then
    fj release asset create -H git.m0sh1.cc -r "${FORGEJO_REPO}" \
      "${TAG}" "${BOTTLE_FILE}" "${ASSET_NAME}"
  fi
else
  fj release create -H git.m0sh1.cc -r "${FORGEJO_REPO}" \
    --tag "${TAG}" --attach "${BOTTLE_FILE}" \
    --body "ARM64 macOS bottle for fast-cli ${VERSION}" "${TAG}"
fi

fetch_api_json "${forgejo_release_json}" \
  "Authorization: token ${FORGEJO_TOKEN}" \
  "${FORGEJO_API}/repos/${FORGEJO_REPO}/releases/tags/${TAG}"
verify_release_asset forgejo "${forgejo_release_json}" \
  "Authorization: token ${FORGEJO_TOKEN}"

github_release_json="${TMP_DIR}/github-release.json"
if fetch_api_json "${github_release_json}" \
  "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${TAG}"
then
  if ! verify_release_asset github "${github_release_json}" \
    "Authorization: Bearer ${GITHUB_TOKEN}"
  then
    GH_TOKEN="${GITHUB_TOKEN}" gh release upload "${TAG}" "${BOTTLE_FILE}" \
      --repo "${GITHUB_REPO}"
  fi
else
  GH_TOKEN="${GITHUB_TOKEN}" gh release create "${TAG}" "${BOTTLE_FILE}" \
    --repo "${GITHUB_REPO}" --verify-tag \
    --title "fast-cli ${VERSION}" \
    --notes "ARM64 macOS bottle for fast-cli ${VERSION}"
fi

fetch_api_json "${github_release_json}" \
  "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${TAG}"
verify_release_asset github "${github_release_json}" \
  "Authorization: Bearer ${GITHUB_TOKEN}"

echo "published fast-cli ${VERSION} bottle to Forgejo and GitHub"
