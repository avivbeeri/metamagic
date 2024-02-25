#!/bin/bash
# Check if working directory clean
if [ -z "$(git status --porcelain)" ]; then 
  # Update config with new version
  jq -M ".version=\"$1\"" config.json > config.swap.json
  cat config.swap.json > config.json
  rm -f config.swap.json

  # Commit version change
  git add config.json
  git commit -m "$1"
  git tag -afm "$1" "$1"

  # build and deploy
  dome nest -c res data *.wren
  mv game.egg ../dome-builds/brazier
  cp config.json ../dome-builds/brazier
  cd ../dome-builds/brazier
  ./upload-all.sh $1 $2
else 
  echo "There are uncommitted changes, please commit first."
  # Uncommitted changes
fi
