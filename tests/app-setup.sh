#!/usr/bin/env bash
set -e
basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
initcmd="bin/mdc exec -T webserver php admin/tool/behat/cli/init.php"

export MOODLE_DOCKER_WWWROOT="${basedir}/moodle"
export MOODLE_DOCKER_BROWSER="chrome"

if [ "$SUITE" = "app-development" ];
then
    export MOODLE_DOCKER_APP_PATH="${basedir}/app"

    git clone --branch "$MOODLE_DOCKER_APP_VERSION" --depth 1 https://github.com/moodlehq/moodleapp $basedir/app
    git clone --branch "$MOODLE_DOCKER_APP_VERSION" --depth 1 https://github.com/moodlehq/moodle-local_moodleappbehat $basedir/moodle/local/moodleappbehat

    if [[ $RUNTIME = ionic5 ]];
    then
        docker run --volume $basedir/app:/app --workdir /app node:14 bash -c "npm install npm@7 -g && npm ci"
    else
        docker run --volume $basedir/app:/app --workdir /app node:11 npm run setup
        docker run --volume $basedir/app:/app --workdir /app node:11 npm ci
    fi
elif [ "$SUITE" = "app" ];
then
    isdevelop=`echo $MOODLE_DOCKER_APP_VERSION | grep -E -o "(next)|(latest)"`

    branch="latest"
    if [ "$isdevelop" = "next" ];
    then
        branch="main"
    fi

    git clone --branch "$branch" --depth 1 https://github.com/moodlehq/moodle-local_moodleappbehat $basedir/moodle/local/moodleappbehat
else
    echo "Error, unknown suite '$SUITE'"
    exit 1
fi

cp $basedir/assets/appbehattests/app.feature $basedir/moodle/local/moodleappbehat/tests/behat/app.feature

echo "Pulling docker images"
$basedir/bin/mdc pull
echo "Starting up container"
$basedir/bin/mdc up -d
echo "Waiting for DB to come up"
$basedir/bin/moodle-docker-wait-for-db
echo "Waiting for Moodle app to come up"
$basedir/bin/moodle-docker-wait-for-app
echo "Running: $initcmd"
$basedir/$initcmd
