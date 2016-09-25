#!/bin/bash -e

REPO=../auto-opam-repository
UPSTREAM=git://github.com/ocaml/opam-repository
GEN=`pwd`/generate.native
PULL=`pwd`/create_pull_request.native
if [ ! -d ${REPO} ]; then
  git clone git@github.com:bactrian/opam-repository ${REPO}
fi

BRANCH=sync-prs-`date +%s`
HRDATE=`date +%c`
cd $REPO
# @@DRA Cleaner to ensure that origin/upstream is same as $UPSTREAM
#       and do a fetch followed by hard reset to upstream
git checkout -f master
git reset --hard
git pull $UPSTREAM master
git checkout -b $BRANCH

# This becomes a little less scary-looking in OPAM 2.0 when it's packages/ocaml/*+pr[0-9]*
rm -rf compilers/*/*+pr[0-9]*
printf "Creating switches"
# IFS must be empty or multiple spaces coming out of $GEN will be squashed!
IFS=''
while IFS=' ' read -r pr user repo branch target url
do
  read -r descr
  printf "."
  VERSION=$(curl -s https://raw.githubusercontent.com/$user/$repo/$branch/VERSION | head -n 1)
  VERSION=${VERSION%+*}
  # trunk was mis-tagged 4.03.1 for a while
  if [[ $target == "trunk" && $VERSION == "4.03.1" ]] ; then
    VERSION=4.04.0
  fi
  # Uncomment below to get the old behaviour
#  VERSION=4.05.0
  NAME=$VERSION+pr$pr
  DIR=compilers/$VERSION/$NAME
  mkdir -p $DIR
  printf "%s" "$descr" > $DIR/$NAME.descr
  cat > $DIR/$NAME.comp <<EOF
opam-version: "1"
version: "$VERSION"
src: "$url"
build: [
  ["./configure" "-prefix" prefix "-with-debug-runtime"]
  [make "world"]
  [make "world.opt"]
  [make "install"]
]
packages: [ "base-unix" "base-bigarray" "base-threads" ]
env: [[CAML_LD_LIBRARY_PATH = "%{lib}%/stublibs"]]
EOF
done <<< $($GEN)
echo

git add compilers
git commit -a -m 'Sync latest compiler pull requests' || true
git push origin $BRANCH
$PULL -h $BRANCH -m "The latest compiler pull requests for OCaml $V as of
$HRDATE" -t "Sync OCaml compiler PRs" -b master -r opam-repository -u bactrian \
  -x ocaml -k infra
