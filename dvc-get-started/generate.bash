#!/bin/bash
# See https://dvc.org/doc/start

# Setup script env:
#   e   Exit immediately if a command exits with a non-zero exit status.
#   u   Treat unset variables as an error when substituting.
#   x   Print commands and their arguments as they are executed.
set -eux

export HERE="$( cd "$(dirname "$0")" ; pwd -P )"
export REPO_NAME="dvc-get-started-$(date +%F-%H-%M-%S)"
export REPO_PATH="${HERE}/build/${REPO_NAME}"
export PUSH_SCRIPT="${HERE}/build/push-${REPO_NAME}.sh"

if [ -d "$REPO_PATH" ]; then
    echo "Repo $REPO_PATH already exists, please remove it first."
    exit 1
fi

mkdir -p $REPO_PATH
pushd $REPO_PATH

virtualenv -p python3 .venv
export VIRTUAL_ENV_DISABLE_PROMPT=true
source .venv/bin/activate
echo '.venv/' > .gitignore

pip install "git+https://github.com/iterative/dvc#egg=dvc[all]"


git init
git checkout -b base
cp $HERE/code-main/README.md .
git add .
git commit -m  "Initialize Git repository"
git tag -a "base-0-git-init" -m "Git initialized."


dvc init
git commit -m "Initialize DVC project"
git tag -a "base-1-dvc-init" -m "DVC initialized."

# Remote active on this env only, for writing to HTTP redirect below.
dvc remote add -d --local storage s3://dvc-public/remote/get-started
# Actual remote for generated project (read-only). Redirect of S3 bucket above.
dvc remote add -d storage https://remote.dvc.org/get-started
git add .
git commit -m "Configure default remote"
git tag -a "base-2-config-remote" -m "Read-only remote storage configured."

# Create the checkpoints branch
exec ${HERE}/generate-checkpoints.bash
# Create the main branch 
exec ${HERE}/generate-main.bash


popd

cat > ${PUSH_SCRIPT} <<EOF
#!/bin/sh

set -eux

# The Git repo generated by this script is intended to be published on
# https://github.com/iterative/dvc-get-started. Make sure the Github repo
# exists first and that you have appropriate write permissions.

# If the Github repo already exists, run these commands to rewrite it:

cd ${HERE}/build/${REPO_NAME}
git remote add origin git@github.com:iterative/dvc-get-started.git
git push --force origin master
git push --force origin --tags
# dvc exp list --all --names-only | xargs -n 1 dvc exp push origin
cd -


EOF

cat ${PUSH_SCRIPT}
echo "##########################"
echo "Push script is written to: ${PUSH_SCRIPT}"
echo "You can run it with"
echo "$ chmod u+x ${PUSH_SCRIPT}"
echo "$ ${PUSH_SCRIPT}"
echo "You may remove the generated repo with:"
echo "$ rm -fR ${REPO_PATH}"


unset HERE
unset REPO_NAME
unset REPO_PATH
unset PUSH_SCRIPT
