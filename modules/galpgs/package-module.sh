#!/usr/bin/env bash

set -eu

umask 002
unset PYTHONPATH

echo "##########################"
echo
echo "module_dir = ${module_dir:=/g/data/v10/private/modules}"
echo "agdc_module_dir = ${agdc_module_dir:=/g/data/v10/public/modules}"
echo
# NBAR needs py2, so it's still the default
echo "agdc_instance_module = ${agdc_instance_module:=agdc-py3-prod/1.2.0}"
agdc_instance_module_name=${agdc_instance_module%/*}
instance=${agdc_instance_module_name##*-}
echo "instance = ${instance}"
echo
echo "eodatasets_head = ${eodatasets_head:=eodatasets-0.9}"
echo "gqa_head = ${gqa_head:=gqa-0.9}"
echo "gaip_head = ${gaip_head:=develop}"
echo
echo "##########################"
export module_dir agdc_instance_module pyvariant 

echoerr() { echo "$@" 1>&2; }

if [[ $# != 1 ]] || [[ "$1" == "--help" ]];
then
    echoerr
    echoerr "Usage: $0 <version>"
    exit 1
fi
export version="$1"

module use ${module_dir}/modulefiles
module use -a ${agdc_module_dir}/modulefiles
module load ${agdc_instance_module}

python_version=`python -c 'from __future__ import print_function; import sys; print("%s.%s"%sys.version_info[:2])'`
python_major=`python -c 'from __future__ import print_function; import sys; print(sys.version_info[0])'`
subvariant=py${python_major}


function installrepo() {
    destination_name=$1
    head=${2:=develop}
    repo=$3

    repo_cache="cache/${destination_name}.git"

    if [ -e "${repo_cache}" ]
    then
        pushd "${repo_cache}"
            git remote update
        popd
    else
        git clone --mirror "${repo}" "${repo_cache}"
    fi

    build_dest="build/${destination_name}"
    [ -e "${build_dest}" ] && rm -rf "${build_dest}"
    git clone -b $head "${repo_cache}" "${build_dest}"

    pushd "${build_dest}"
        rm -r dist build || true
        python setup.py sdist
        pip install dist/*.tar.gz "--prefix=${package_dest}"
    popd
}

export package_name=galpgs-${subvariant}-${instance}
export package_description="GA lpgs processing"

export package_dest=${module_dir}/${package_name}/${version}
export python_dest=${package_dest}/lib/python${python_version}/site-packages

echo '# Packaging '$package_name' '$version' to '$package_dest' #'

read -p "Continue? [y/N]" -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then

    # Setuptools requires the destination to be on the path, as it tests that the target is loadable.
    echo "Creating directory"
    mkdir -v -p "${python_dest}"
    export PYTHONPATH=${PYTHONPATH:+${PYTHONPATH}:}${python_dest}

    installrepo idlfunctions develop git@github.com:sixy6e/idl-functions.git
    installrepo eotools develop git@github.com:GeoscienceAustralia/eo-tools.git
    installrepo eodatasets ${eodatasets_head} git@github.com:GeoscienceAustralia/eo-datasets.git
    installrepo gaip ${gaip_head} git@github.com:jeremyh/gaip.git
    installrepo gqa ${gqa_head} git@github.com:GeoscienceAustralia/gqa.git
    installrepo galpgs ${version} git@github.com:jeremyh/galpgs.git

    modulefile_dir="${module_dir}/modulefiles/${package_name}"
    mkdir -v -p "${modulefile_dir}"

    modulefile_dest="${modulefile_dir}/${version}"
    envsubst < modulefile.template > "${modulefile_dest}"
    echo "Wrote modulefile to ${modulefile_dest}"
fi

rm -rf agdc-v2 > /dev/null 2>&1


echo
echo 'Done.'

