#!/bin/bash

# Fetches upstream resources from docker/docker and docker/distribution
# before handing off the site to Jekyll to build
# Relies on the "ENGINE_BRANCH" and "DISTRIBUTION_BRANCH" environment variables,
# which are usually set by the Dockerfile.
: "${ENGINE_BRANCH?No release branch set for docker/docker and docker/cli}"
: "${DISTRIBUTION_BRANCH?No release branch set for docker/distribution}"

# Helper function to deal with sed differences between osx and Linux
# See https://stackoverflow.com/a/38595160
sedi () {
    sed --version >/dev/null 2>&1 && sed -i -- "$@" || sed -i "" "$@"
}

# Assume non-local mode until we check for -l
LOCAL=0

while getopts ":hl" opt; do
  case ${opt} in
    l ) LOCAL=1
        echo "Running in local mode"
        break
      ;;
    \? ) echo "Usage: $0 [-h] | -l"
         echo "When running in local mode, operates on the current working directory."
         echo "Otherwise, operates on md_source in the scope of the Dockerfile"
         break
      ;;
  esac
done

# Do some sanity-checking to make sure we are running this from the right place
if ! [ -f _config.yml ]; then
  echo "Could not find _config.yml. We may not be in the right place. Bailing."
  exit 1
fi

# Parse some variables from _config.yml and make them available to this script
# This only finds top-level variables with _version in them that don't have any
# leading space. This is brittle!

while read i; do
  # Store the key as a variable name and the value as the variable value
  varname=$(echo "$i" | sed 's/"//g' | awk -F ':' {'print $1'} | tr -d '[:space:]')
  varvalue=$(echo "$i" | sed 's/"//g' | awk -F ':' {'print $2'} | tr -d '[:space:]')
  echo "Setting \$${varname} to $varvalue"
  declare "$varname=$varvalue"
done < <(cat ./_config.yml |grep '_version:' |grep '^[a-z].*')

# Replace variable in toc.yml with value from above
sedi "s/{{ site.latest_engine_api_version }}/$latest_engine_api_version/g" ./_data/toc.yaml

# Translate branches for use by svn
engine_svn_branch="branches/${ENGINE_BRANCH}"
if [ engine_svn_branch = "branches/master" ]; then
	engine_svn_branch=trunk
fi
distribution_svn_branch="branches/${DISTRIBUTION_BRANCH}"
if [ distribution_svn_branch = "branches/master" ]; then
	distribution_svn_branch=trunk
fi

# Directories to get via SVN. We use this because you can't use git to clone just a portion of a repository
svn co "https://github.com/docker/docker-ce/${engine_svn_branch}/components/cli/docs/extend" ./engine/extend || (echo "Failed engine/extend download" && exit 1)
svn co "https://github.com/docker/docker-ce/${engine_svn_branch}/components/engine/docs/api" ./engine/api    || (echo "Failed engine/api download" && exit 1) # This will only get you the old API MD files 1.18 through 1.24
svn co "https://github.com/docker/distribution/${distribution_svn_branch}/docs/spec" ./registry/spec         || (echo "Failed registry/spec download" && exit 1)
svn co "https://github.com/mirantis/compliance/trunk/docs/compliance" ./compliance                           || (echo "Failed docker/compliance download" && exit 1)

# Get the Engine APIs that are in Swagger
# Be careful with the locations on Github for these
# When you change this you need to make sure to copy the previous
# directory into a new one in the docs git and change the index.html
wget --quiet --directory-prefix=./engine/api/v1.25/ https://raw.githubusercontent.com/docker/docker/v1.13.0/api/swagger.yaml                    || (echo "Failed 1.25 swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/api/v1.26/ https://raw.githubusercontent.com/docker/docker/v17.03.0-ce/api/swagger.yaml                || (echo "Failed 1.26 swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/api/v1.27/ https://raw.githubusercontent.com/docker/docker/v17.03.1-ce/api/swagger.yaml                || (echo "Failed 1.27 swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/api/v1.28/ https://raw.githubusercontent.com/docker/docker/v17.04.0-ce/api/swagger.yaml                || (echo "Failed 1.28 swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/api/v1.29/ https://raw.githubusercontent.com/docker/docker/v17.05.0-ce/api/swagger.yaml                || (echo "Failed 1.29 swagger download" && exit 1)
# New location for swagger.yaml for 17.06+
wget --quiet --directory-prefix=./engine/api/v1.30/ https://raw.githubusercontent.com/docker/docker-ce/v17.06.2-ce/components/engine/api/swagger.yaml || (echo "Failed 1.30 swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/api/v1.31/ https://raw.githubusercontent.com/docker/docker-ce/v17.07.0-ce/components/engine/api/swagger.yaml || (echo "Failed 1.31 swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/api/v1.32/ https://raw.githubusercontent.com/docker/docker-ce/v17.09.1-ce/components/engine/api/swagger.yaml || (echo "Failed 1.32 swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/api/v1.33/ https://raw.githubusercontent.com/docker/docker-ce/v17.10.0-ce/components/engine/api/swagger.yaml || (echo "Failed 1.33 swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/api/v1.34/ https://raw.githubusercontent.com/docker/docker-ce/v17.11.0-ce/components/engine/api/swagger.yaml || (echo "Failed 1.34 swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/api/v1.35/ https://raw.githubusercontent.com/docker/docker-ce/v17.12.1-ce/components/engine/api/swagger.yaml || (echo "Failed 1.35 swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/api/v1.36/ https://raw.githubusercontent.com/docker/docker-ce/v18.02.0-ce/components/engine/api/swagger.yaml || (echo "Failed 1.36 swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/api/v1.37/ https://raw.githubusercontent.com/docker/docker-ce/v18.03.1-ce/components/engine/api/swagger.yaml || (echo "Failed 1.37 swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/api/v1.38/ https://raw.githubusercontent.com/docker/docker-ce/v18.06.3-ce/components/engine/api/swagger.yaml || (echo "Failed 1.38 swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/api/v1.39/ https://raw.githubusercontent.com/docker/docker-ce/v18.09.9/components/engine/api/swagger.yaml    || (echo "Failed 1.39 swagger download" && exit 1)

# Get a few one-off files that we use directly from upstream
wget --quiet --directory-prefix=./engine/api/v"${latest_engine_api_version}"/ "https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/engine/api/swagger.yaml"     || (echo "Failed ${latest_engine_api_version} swagger download" && exit 1)
wget --quiet --directory-prefix=./engine/                       "https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/deprecated.md"                    || (echo "Failed engine/deprecated.md download" && exit 1)
wget --quiet --directory-prefix=./engine/reference/             "https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/builder.md"             || (echo "Failed engine/reference/builder.md download" && exit 1)
wget --quiet --directory-prefix=./engine/reference/             "https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/run.md"                 || (echo "Failed engine/reference/run.md download" && exit 1)
wget --quiet --directory-prefix=./engine/reference/commandline/ "https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/commandline/cli.md"     || (echo "Failed engine/reference/commandline/cli.md download" && exit 1)
wget --quiet --directory-prefix=./engine/reference/commandline/ "https://raw.githubusercontent.com/docker/docker-ce/${ENGINE_BRANCH}/components/cli/docs/reference/commandline/dockerd.md" || (echo "Failed engine/reference/commandline/dockerd.md download" && exit 1)
wget --quiet --directory-prefix=./registry/                     "https://raw.githubusercontent.com/docker/distribution/${DISTRIBUTION_BRANCH}/docs/configuration.md"                       || (echo "Failed registry/configuration.md download" && exit 1)

# Remove things we don't want in the build
rm ./registry/spec/api.md.tmpl
rm -rf ./apidocs/cloud-api-source
rm -rf ./tests
