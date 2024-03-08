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
  dome nest -c ui res data *.wren
  mv game.egg ../dome-builds/arcanist
  cp config.json ../dome-builds/arcanist
  cd ../dome-builds/arcanist
  ./upload-all.sh $1 $2
else 
  echo "There are uncommitted changes, please commit first."
  # Uncommitted changes
fi
